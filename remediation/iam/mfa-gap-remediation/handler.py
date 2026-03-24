"""
FORGE Remediation Module: FORGE-IAM-003
Detect IAM users without MFA and force-disable their console access.

Trigger:  AWS Config → EventBridge → Lambda
Controls: NIST IA-2, IA-2(1) | SOC2 CC6.1 | HIPAA 164.312(d) | FFIEC IS.10
"""

import boto3
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client("iam")


def lambda_handler(event: dict, context) -> dict:
    logger.info(json.dumps({"event": event}))

    config_item = event.get("detail", {}).get("configurationItem", {})
    user_name = config_item.get("resourceName")

    if not user_name:
        logger.error("Cannot determine IAM username from event")
        return {"status": "ERROR", "message": "No username in event"}

    return _remediate(user_name)


def _remediate(user_name: str) -> dict:
    audit = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "control_id": "FORGE-IAM-003",
        "resource_type": "AWS::IAM::User",
        "resource": user_name,
        "action": "disable_console_access_no_mfa",
        "trigger": "automated_remediation",
    }
    logger.info(json.dumps(audit))

    try:
        # Check if MFA is enrolled
        mfa_devices = iam.list_mfa_devices(UserName=user_name)["MFADevices"]

        if mfa_devices:
            logger.info(f"User {user_name} has MFA — no action required")
            return {"status": "NO_ACTION", "control": "FORGE-IAM-003", "resource": user_name}

        # No MFA — delete login profile (disables console access)
        try:
            iam.delete_login_profile(UserName=user_name)
            logger.warning(
                f"[FORGE-IAM-003] Disabled console access for {user_name} — no MFA enrolled"
            )
        except iam.exceptions.NoSuchEntityException:
            logger.info(f"User {user_name} has no console login profile, skipping")

        return {
            "status": "SUCCESS",
            "control": "FORGE-IAM-003",
            "resource": user_name,
            "action": "console_access_disabled_no_mfa",
        }

    except Exception as exc:
        logger.error(f"[FORGE-IAM-003] Remediation failed for {user_name}: {exc}")
        raise
