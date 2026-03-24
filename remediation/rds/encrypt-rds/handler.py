"""
FORGE Remediation Module: FORGE-RDS-001
Enable encryption at rest for non-compliant RDS instances.

NOTE: RDS encryption cannot be enabled on a live instance — it requires
creating an encrypted snapshot and restoring. This module creates a
notification and action plan rather than performing a live destructive change.
The restore workflow is documented in docs/runbooks/rds-encryption-remediation.md

Trigger:  AWS Config → EventBridge → Lambda
Controls: NIST SC-28 | SOC2 CC6.7 | HIPAA 164.312(a)(2)(iv)
"""

import boto3
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rds = boto3.client("rds")
sns = boto3.client("sns")

import os
ALERT_TOPIC_ARN = os.environ.get("ALERT_TOPIC_ARN", "")


def lambda_handler(event: dict, context) -> dict:
    logger.info(json.dumps({"event": event}))

    config_item = event.get("detail", {}).get("configurationItem", {})
    db_instance_id = config_item.get("resourceName") or config_item.get("resourceId")

    if not db_instance_id:
        return {"status": "ERROR", "message": "No DB instance ID in event"}

    return _remediate(db_instance_id)


def _remediate(db_instance_id: str) -> dict:
    audit = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "control_id": "FORGE-RDS-001",
        "resource_type": "AWS::RDS::DBInstance",
        "resource": db_instance_id,
        "action": "notify_encryption_gap",
        "trigger": "automated_remediation",
        "note": "RDS encryption requires snapshot-restore. Manual runbook required.",
    }
    logger.info(json.dumps(audit))

    # Notify security team with runbook link
    if ALERT_TOPIC_ARN:
        message = (
            f"FORGE-RDS-001: RDS instance {db_instance_id} is NOT encrypted at rest.\n"
            f"Automated live remediation is not safe for RDS encryption.\n"
            f"Follow runbook: docs/runbooks/rds-encryption-remediation.md\n"
            f"Timestamp: {audit['timestamp']}"
        )
        sns.publish(
            TopicArn=ALERT_TOPIC_ARN,
            Subject=f"[FORGE] RDS Encryption Gap Detected: {db_instance_id}",
            Message=message,
        )
        logger.warning(f"[FORGE-RDS-001] Alert sent for unencrypted RDS: {db_instance_id}")

    return {
        "status": "NOTIFICATION_SENT",
        "control": "FORGE-RDS-001",
        "resource": db_instance_id,
        "action": "manual_runbook_required",
        "runbook": "docs/runbooks/rds-encryption-remediation.md",
    }
