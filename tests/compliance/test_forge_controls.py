"""
FORGE compliance tests — verify AWS Config rules are evaluating correctly.

These tests run against a LIVE AWS environment and validate that the FORGE
Config rules exist and are returning expected compliance results.

Requirements:
    pip install boto3 pytest

Usage:
    AWS_PROFILE=<your-profile> pytest tests/compliance/test_forge_controls.py -v
"""

import os
import time
import pytest
import boto3


REGION = os.environ.get("AWS_REGION", "us-east-1")


@pytest.fixture(scope="module")
def config_client():
    return boto3.client("config", region_name=REGION)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def get_rule_compliance(config_client, rule_name: str) -> dict:
    """Return summary compliance for a single Config rule."""
    resp = config_client.get_compliance_summary_by_config_rule(
        ConfigRuleNames=[rule_name]
    )
    for item in resp.get("ComplianceSummariesByConfigRule", []):
        if item["ConfigRuleName"] == rule_name:
            return item.get("Compliance", {})
    return {}


def rule_exists(config_client, rule_name: str) -> bool:
    try:
        config_client.describe_config_rules(ConfigRuleNames=[rule_name])
        return True
    except config_client.exceptions.NoSuchConfigRuleException:
        return False


# ---------------------------------------------------------------------------
# Tests — Rule Existence
# ---------------------------------------------------------------------------

EXPECTED_RULES = [
    "FORGE-S3-001",
    "FORGE-S3-002",
    "FORGE-S3-003",
    "FORGE-S3-004",
    "FORGE-S3-005",
    "FORGE-IAM-001",
    "FORGE-IAM-002",
    "FORGE-IAM-003",
    "FORGE-IAM-004",
    "FORGE-IAM-005",
    "FORGE-IAM-006",
    "FORGE-EC2-001",
    "FORGE-EC2-002",
    "FORGE-EC2-003",
    "FORGE-RDS-001",
    "FORGE-RDS-002",
    "FORGE-RDS-003",
    "FORGE-RDS-004",
    "FORGE-CT-001",
    "FORGE-CT-002",
    "FORGE-CT-003",
    "FORGE-CT-004",
    "FORGE-KMS-001",
    "FORGE-GD-001",
]


@pytest.mark.parametrize("rule_name", EXPECTED_RULES)
def test_config_rule_exists(config_client, rule_name):
    """All FORGE Config rules must exist in this account/region."""
    assert rule_exists(config_client, rule_name), (
        f"Config rule '{rule_name}' not found. "
        "Have you applied the modules/security/config-rules Terraform module?"
    )


# ---------------------------------------------------------------------------
# Tests — Config Recorder Running
# ---------------------------------------------------------------------------

def test_config_recorder_is_running(config_client):
    """AWS Config recorder must be active and delivering."""
    resp = config_client.describe_configuration_recorder_status()
    recorders = resp.get("ConfigurationRecordersStatus", [])
    assert recorders, "No Config recorders found — deploy modules/security/config-rules"
    assert any(r["recording"] is True for r in recorders), (
        "Config recorder found but is NOT recording. Check delivery channel."
    )


def test_config_delivery_channel_exists(config_client):
    """A delivery channel must exist so findings reach S3/SNS."""
    resp = config_client.describe_delivery_channels()
    assert resp.get("DeliveryChannels"), "No Config delivery channel defined."


# ---------------------------------------------------------------------------
# Tests — S3 Controls
# ---------------------------------------------------------------------------

def test_s3_public_access_not_compliant_count(config_client):
    """There should be zero NON_COMPLIANT S3 buckets for FORGE-S3-001."""
    compliance = get_rule_compliance(config_client, "FORGE-S3-001")
    non_compliant = (
        compliance.get("ComplianceSummary", {})
        .get("NonCompliantResourceCount", {})
        .get("CappedCount", 0)
    )
    assert non_compliant == 0, (
        f"FORGE-S3-001: {non_compliant} buckets still have public access enabled. "
        "Check remediation/s3/block-public-access Lambda logs."
    )


# ---------------------------------------------------------------------------
# Tests — IAM Controls
# ---------------------------------------------------------------------------

def test_mfa_gaps_not_compliant_count(config_client):
    """Zero IAM users should be flagged by FORGE-IAM-003 (MFA gap test)."""
    compliance = get_rule_compliance(config_client, "FORGE-IAM-003")
    non_compliant = (
        compliance.get("ComplianceSummary", {})
        .get("NonCompliantResourceCount", {})
        .get("CappedCount", 0)
    )
    assert non_compliant == 0, (
        f"FORGE-IAM-003: {non_compliant} IAM users are missing MFA. "
        "Check remediation/iam/mfa-gap-remediation Lambda or enforce via IAM Identity Center."
    )


# ---------------------------------------------------------------------------
# Tests — Encryption Controls
# ---------------------------------------------------------------------------

def test_ebs_encryption_defaults_compliant(config_client):
    """FORGE-EC2-001 should have zero NON_COMPLIANT instances."""
    compliance = get_rule_compliance(config_client, "FORGE-EC2-001")
    non_compliant = (
        compliance.get("ComplianceSummary", {})
        .get("NonCompliantResourceCount", {})
        .get("CappedCount", 0)
    )
    assert non_compliant == 0, (
        f"FORGE-EC2-001: {non_compliant} accounts/regions have unencrypted EBS. "
        "Check remediation/ec2/encrypt-ebs Lambda logs."
    )


def test_rds_encryption_compliant(config_client):
    """FORGE-RDS-001 should report zero unencrypted RDS instances."""
    if not rule_exists(config_client, "FORGE-RDS-001"):
        pytest.skip("FORGE-RDS-001 rule not present in this environment.")
    compliance = get_rule_compliance(config_client, "FORGE-RDS-001")
    non_compliant = (
        compliance.get("ComplianceSummary", {})
        .get("NonCompliantResourceCount", {})
        .get("CappedCount", 0)
    )
    assert non_compliant == 0, (
        f"FORGE-RDS-001: {non_compliant} RDS instances are unencrypted. "
        "Follow docs/runbooks/rds-encryption-remediation.md."
    )


# ---------------------------------------------------------------------------
# Tests — CloudTrail Controls
# ---------------------------------------------------------------------------

def test_cloudtrail_enabled(config_client):
    """FORGE-CT-001 — CloudTrail must be active."""
    # CLOUD_TRAIL_ENABLED is a periodic/account-level rule — it has no per-resource
    # compliance counts, so use describe_compliance_by_config_rule to get the rule-level
    # compliance type (COMPLIANT | NON_COMPLIANT | INSUFFICIENT_DATA).
    resp = config_client.describe_compliance_by_config_rule(
        ConfigRuleNames=["FORGE-CT-001"],
    )
    items = resp.get("ComplianceByConfigRules", [])
    assert items, "FORGE-CT-001: Rule not found — deploy modules/security/config-rules."
    compliance_type = items[0].get("Compliance", {}).get("ComplianceType", "INSUFFICIENT_DATA")
    assert compliance_type == "COMPLIANT", (
        f"FORGE-CT-001: CloudTrail rule compliance is '{compliance_type}'. "
        "Ensure CloudTrail is enabled — deploy modules/foundation/logging."
    )


def test_cloudtrail_log_file_validation_enabled(config_client):
    """FORGE-CT-003 — Log file validation must be on."""
    compliance = get_rule_compliance(config_client, "FORGE-CT-003")
    non_compliant = (
        compliance.get("ComplianceSummary", {})
        .get("NonCompliantResourceCount", {})
        .get("CappedCount", 0)
    )
    assert non_compliant == 0, (
        "FORGE-CT-003: CloudTrail log file validation is disabled."
    )


# ---------------------------------------------------------------------------
# Tests — Security Services
# ---------------------------------------------------------------------------

def test_guardduty_enabled():
    """GuardDuty must have at least one active detector."""
    gd = boto3.client("guardduty", region_name=REGION)
    detectors = gd.list_detectors().get("DetectorIds", [])
    assert detectors, "No GuardDuty detectors found — deploy modules/security/guardduty"
    status = gd.get_detector(DetectorId=detectors[0])
    assert status["Status"] == "ENABLED", "GuardDuty detector is not ENABLED."


def test_security_hub_enabled():
    """Security Hub must be enabled."""
    sh = boto3.client("securityhub", region_name=REGION)
    try:
        hub = sh.describe_hub()
        assert hub.get("HubArn"), "Security Hub HubArn is empty."
    except sh.exceptions.InvalidAccessException:
        pytest.fail("Security Hub is not enabled — deploy modules/security/security-hub")
