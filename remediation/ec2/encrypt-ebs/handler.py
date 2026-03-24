"""
FORGE Remediation Module: FORGE-EC2-001
Enable EBS encryption by default for accounts where it is disabled.

Trigger:  AWS Config → EventBridge → Lambda
Controls: NIST SC-28 | SOC2 CC6.7 | HIPAA 164.312(a)(2)(iv)
"""

import boto3
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")


def lambda_handler(event: dict, context) -> dict:
    logger.info(json.dumps({"event": event}))

    # For account-level controls the "resource" is the account itself
    config_item = event.get("detail", {}).get("configurationItem", {})
    account_id = config_item.get("awsAccountId") or event.get("account")

    if not account_id:
        logger.error("Cannot determine account ID from event")
        return {"status": "ERROR", "message": "No account ID in event"}

    return _remediate(account_id)


def _remediate(account_id: str) -> dict:
    audit = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "control_id": "FORGE-EC2-001",
        "resource_type": "AWS::EC2::AccountAttribute",
        "resource": account_id,
        "action": "enable_ebs_encryption_by_default",
        "trigger": "automated_remediation",
    }
    logger.info(json.dumps(audit))

    try:
        response = ec2.enable_ebs_encryption_by_default()
        ebs_status = response.get("EbsEncryptionByDefault", False)
        logger.info(f"[FORGE-EC2-001] EBS encryption by default enabled: {ebs_status}")

        return {
            "status": "SUCCESS",
            "control": "FORGE-EC2-001",
            "resource": account_id,
            "action": "ebs_encryption_enabled",
            "ebs_encryption_by_default": ebs_status,
        }

    except Exception as exc:
        logger.error(f"[FORGE-EC2-001] Remediation failed: {exc}")
        raise
