"""
FORGE Remediation Module: FORGE-S3-001
Block Public Access on non-compliant S3 buckets.

Trigger:  AWS Config → EventBridge → Lambda
Controls: NIST AC-3, SC-7 | SOC2 CC6.1 | FFIEC IS.10
"""

import boto3
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")


def lambda_handler(event: dict, context) -> dict:
    """
    Receives an EventBridge event from AWS Config NON_COMPLIANT evaluation
    and blocks public access on the offending S3 bucket.
    """
    logger.info(json.dumps({"event": event}))

    # Support both Config remediation action events and EventBridge rule events
    config_item = (
        event.get("detail", {}).get("configurationItem")
        or event.get("resourceId")
    )

    if isinstance(config_item, dict):
        bucket_name = config_item.get("resourceName") or config_item.get("resourceId")
    else:
        bucket_name = config_item  # plain string resource ID

    if not bucket_name:
        logger.error("Cannot determine bucket name from event")
        return _error_response("No bucket name in event")

    return _remediate(bucket_name)


def _remediate(bucket_name: str) -> dict:
    audit = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "control_id": "FORGE-S3-001",
        "resource_type": "AWS::S3::Bucket",
        "resource": bucket_name,
        "action": "block_public_access",
        "trigger": "automated_remediation",
    }
    logger.info(json.dumps(audit))

    try:
        # Verify bucket still exists before attempting remediation
        s3.head_bucket(Bucket=bucket_name)
    except s3.exceptions.ClientError as exc:
        code = exc.response["Error"]["Code"]
        if code in ("404", "NoSuchBucket"):
            logger.warning(f"Bucket {bucket_name} no longer exists, skipping")
            return _success_response(bucket_name, "bucket_not_found_skipped")
        raise

    try:
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            },
        )
        logger.info(f"[FORGE-S3-001] Blocked public access on: {bucket_name}")
        return _success_response(bucket_name, "public_access_blocked")

    except Exception as exc:
        logger.error(f"[FORGE-S3-001] Remediation failed for {bucket_name}: {exc}")
        raise


def _success_response(resource: str, action: str) -> dict:
    return {
        "status": "SUCCESS",
        "control": "FORGE-S3-001",
        "resource": resource,
        "action": action,
    }


def _error_response(message: str) -> dict:
    return {"status": "ERROR", "control": "FORGE-S3-001", "message": message}
