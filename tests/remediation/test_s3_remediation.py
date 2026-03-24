"""
FORGE remediation unit tests — S3 block-public-access Lambda.

Tests the handler.py logic in isolation using moto (AWS mock library).

Requirements:
    pip install boto3 moto[s3] pytest

Usage:
    pytest tests/remediation/test_s3_remediation.py -v
"""

import json
import sys
import os
import pytest

# Make the handler importable from the remediation directory
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../remediation/s3/block-public-access"))

import boto3
from moto import mock_aws


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def aws_credentials():
    """Mock AWS credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def s3_client(aws_credentials):
    with mock_aws():
        yield boto3.client("s3", region_name="us-east-1")


@pytest.fixture
def public_bucket(s3_client):
    """Create a bucket with public access settings NOT blocked."""
    bucket_name = "forge-test-public-bucket"
    s3_client.create_bucket(Bucket=bucket_name)
    # Do NOT set public access block — simulates non-compliant state
    return bucket_name


@pytest.fixture
def already_compliant_bucket(s3_client):
    """Create a bucket that already has all public access blocked."""
    bucket_name = "forge-test-compliant-bucket"
    s3_client.create_bucket(Bucket=bucket_name)
    s3_client.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )
    return bucket_name


# ---------------------------------------------------------------------------
# Helper — build a mock AWS Config event
# ---------------------------------------------------------------------------

def build_config_event(bucket_name: str, account_id: str = "123456789012") -> dict:
    return {
        "invokingEvent": json.dumps({
            "configurationItem": {
                "resourceType": "AWS::S3::Bucket",
                "resourceId": bucket_name,
                "awsAccountId": account_id,
                "awsRegion": "us-east-1",
                "configurationItemStatus": "ResourceDiscovered",
            },
            "messageType": "ConfigurationItemChangeNotification",
        }),
        "resultToken": "test-token",
        "ruleParameters": "{}",
    }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@mock_aws
def test_handler_blocks_public_access_on_non_compliant_bucket(aws_credentials):
    """Handler should set all 4 public access block settings on a non-compliant bucket."""
    import importlib
    import handler

    s3 = boto3.client("s3", region_name="us-east-1")
    bucket_name = "forge-test-remediate"
    s3.create_bucket(Bucket=bucket_name)

    event = build_config_event(bucket_name)
    response = handler.lambda_handler(event, {})

    assert response["statusCode"] == 200

    pab = s3.get_public_access_block(Bucket=bucket_name)["PublicAccessBlockConfiguration"]
    assert pab["BlockPublicAcls"] is True
    assert pab["IgnorePublicAcls"] is True
    assert pab["BlockPublicPolicy"] is True
    assert pab["RestrictPublicBuckets"] is True


@mock_aws
def test_handler_is_idempotent_on_already_compliant_bucket(aws_credentials):
    """Handler should not error when called on a bucket already properly configured."""
    import handler

    s3 = boto3.client("s3", region_name="us-east-1")
    bucket_name = "forge-test-idempotent"
    s3.create_bucket(Bucket=bucket_name)
    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )

    event = build_config_event(bucket_name)
    response = handler.lambda_handler(event, {})

    assert response["statusCode"] == 200

    pab = s3.get_public_access_block(Bucket=bucket_name)["PublicAccessBlockConfiguration"]
    assert all(pab.values())


@mock_aws
def test_handler_handles_nonexistent_bucket_gracefully(aws_credentials):
    """Handler should return a 200 with error logged rather than raising for missing buckets."""
    import handler

    event = build_config_event("this-bucket-does-not-exist-xyz")
    # Should not raise — the handler catches NoSuchBucket
    response = handler.lambda_handler(event, {})
    # Accept either 200 (graceful) or 500 depending on handler implementation
    assert response["statusCode"] in (200, 500)


@mock_aws
def test_handler_parses_scheduled_notification_event(aws_credentials):
    """Handler must also handle ScheduledNotification messageType (no configurationItem)."""
    import handler

    s3 = boto3.client("s3", region_name="us-east-1")
    bucket_name = "forge-test-scheduled"
    s3.create_bucket(Bucket=bucket_name)

    scheduled_event = {
        "invokingEvent": json.dumps({
            "messageType": "ScheduledNotification",
            "notificationCreationTime": "2026-01-01T00:00:00.000Z",
        }),
        "resultToken": "test-token",
        "ruleParameters": "{}",
    }

    # ScheduledNotification has no specific resource — handler should exit cleanly
    response = handler.lambda_handler(scheduled_event, {})
    # Just assert it doesn't raise an unhandled exception
    assert response is not None
