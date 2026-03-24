"""
FORGE Remediation Module: FORGE-NET-001
Remove 0.0.0.0/0 (any-any) inbound rules from Security Groups.

Trigger:  AWS Config → EventBridge → Lambda
Controls: NIST SC-7, AC-4 | SOC2 CC6.6 | FFIEC IS.10
"""

import boto3
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

# Ports that may never have 0.0.0.0/0 inbound regardless of protocol
BLOCKED_PORTS = {22, 3389, 3306, 5432, 1433, 27017, 6379, 11211}


def lambda_handler(event: dict, context) -> dict:
    logger.info(json.dumps({"event": event}))

    config_item = event.get("detail", {}).get("configurationItem", {})
    sg_id = config_item.get("resourceId") or config_item.get("resourceName")

    if not sg_id:
        logger.error("Cannot determine Security Group ID from event")
        return {"status": "ERROR", "message": "No SG ID in event"}

    return _remediate(sg_id)


def _remediate(sg_id: str) -> dict:
    audit = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "control_id": "FORGE-NET-001",
        "resource_type": "AWS::EC2::SecurityGroup",
        "resource": sg_id,
        "action": "remove_wildcard_inbound_rules",
        "trigger": "automated_remediation",
    }
    logger.info(json.dumps(audit))

    try:
        response = ec2.describe_security_groups(GroupIds=[sg_id])
        sg = response["SecurityGroups"][0]
    except ec2.exceptions.ClientError as exc:
        if exc.response["Error"]["Code"] == "InvalidGroup.NotFound":
            logger.warning(f"Security group {sg_id} not found, skipping")
            return {"status": "NO_ACTION", "control": "FORGE-NET-001", "resource": sg_id}
        raise

    rules_to_revoke = []
    for rule in sg.get("IpPermissions", []):
        for ip_range in rule.get("IpRanges", []):
            if ip_range.get("CidrIp") in ("0.0.0.0/0", "::/0"):
                from_port = rule.get("FromPort", 0)
                to_port = rule.get("ToPort", 65535)
                # Remove any rule covering a blocked port range
                overlaps_blocked = any(
                    from_port <= port <= to_port for port in BLOCKED_PORTS
                )
                if overlaps_blocked:
                    rules_to_revoke.append(rule)
                    break

    if not rules_to_revoke:
        logger.info(f"No violating rules found on {sg_id}")
        return {"status": "NO_ACTION", "control": "FORGE-NET-001", "resource": sg_id}

    ec2.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=rules_to_revoke)
    logger.warning(
        f"[FORGE-NET-001] Revoked {len(rules_to_revoke)} wildcard inbound rules from {sg_id}"
    )

    return {
        "status": "SUCCESS",
        "control": "FORGE-NET-001",
        "resource": sg_id,
        "action": "wildcard_rules_revoked",
        "rules_revoked": len(rules_to_revoke),
    }
