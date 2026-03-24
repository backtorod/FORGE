# Runbook: Incident Response — GuardDuty Finding

**Control Reference:** FORGE-DETECT-001
**Terraform Module:** `modules/security/guardduty`
**Severity Threshold for Page:** HIGH (≥ 7.0)
**Last Reviewed:** 2026-01-01

---

## Overview

GuardDuty findings with severity ≥ 7 trigger an EventBridge rule that
publishes to the FORGE security SNS topic. The on-call engineer receives
an alert and must triage within **15 minutes** (SLA for P1).

---

## Severity Classification

| GuardDuty Severity | FORGE Priority | Response SLA |
|-------------------|----------------|-------------|
| 9.0 – 10.0 (CRITICAL) | P0 | 5 minutes |
| 7.0 – 8.9 (HIGH) | P1 | 15 minutes |
| 4.0 – 6.9 (MEDIUM) | P2 | 4 hours |
| 1.0 – 3.9 (LOW) | P3 | Next business day |

---

## Common Finding Types and Response

### Backdoor:EC2/C&CActivity

**Indicators:** EC2 communicating with known C2 infrastructure.

**Response:**
1. Isolate the instance immediately:
   ```bash
   # Replace values appropriately
   aws ec2 modify-instance-attribute \
     --instance-id i-XXXXXXXXXXXX \
     --groups sg-ISOLATE_SG_ID
   # The isolation SG must allow NO inbound/outbound traffic
   ```
2. Take a forensic snapshot before termination:
   ```bash
   aws ec2 create-snapshot --volume-id vol-XXXX --description "forensic-$(date +%s)"
   ```
3. Terminate the instance.
4. Review CloudTrail for lateral movement from the instance's IAM role.

---

### UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B

**Indicators:** Successful console login from unexpected country/IP.

**Response:**
1. Immediately disable the IAM user login profile:
   ```bash
   aws iam delete-login-profile --user-name SUSPECTED_USER
   ```
2. Deactivate all access keys:
   ```bash
   aws iam list-access-keys --user-name SUSPECTED_USER \
     --query 'AccessKeyMetadata[*].AccessKeyId' --output text | \
   xargs -I {} aws iam update-access-key --access-key-id {} --status Inactive --user-name SUSPECTED_USER
   ```
3. Revoke active sessions using Deny policy:
   ```bash
   # Attach inline deny-all with current time condition
   ```
4. Notify the user through a verified out-of-band channel.
5. Check CloudTrail for actions taken during unauthorized session.

---

### Stealth:S3/ServerAccessLoggingDisabled

**Indicators:** CloudTrail or S3 access logging disabled to cover tracks.

**Response:**
1. Re-enable S3 access logging immediately.
2. Check if core FORGE Log bucket (Object Lock) was targeted — the SCP
   and Object Lock should have prevented deletion.
3. Verify CloudTrail is still active:
   ```bash
   aws cloudtrail get-trail-status --name forge-org-trail \
     --query '{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime}'
   ```
4. Escalate to P0 if the FORGE CloudTrail was stopped — invoke break-glass.

---

### CryptoCurrency:EC2/BitcoinTool.B

**Indicators:** EC2 instance using mining tools.

**Response:**
1. Terminate the instance (cryptomining is resource abuse, not data exfil).
2. Identify how the workload was launched — check CloudTrail for
   `RunInstances` events in the preceding 24 hours.
3. Review IAM role attached to the instance for least-privilege gaps.

---

## General Triage Steps (All Findings)

```bash
# 1. Get finding details
FINDING_ID="arn:aws:guardduty:us-east-1:ACCOUNT:detector/DETECTOR/finding/FINDING"
aws guardduty get-findings \
  --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text) \
  --finding-ids FINDING_ID \
  --query 'Findings[0].{Type:Type,Severity:Severity,Description:Description,Region:Region}'

# 2. Check related CloudTrail events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=AFFECTED_RESOURCE \
  --start-time "$(date -u -v-4H +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}'

# 3. Archive finding after confirmed resolution
aws guardduty archive-findings \
  --detector-id DETECTOR_ID \
  --finding-ids FINDING_ID
```

---

## Escalation Path

| Condition | Action |
|-----------|--------|
| Data exfiltration suspected | Immediately involve Legal / DPO |
| Credentials suspected compromised | Rotate ALL secrets in AWS Secrets Manager |
| Production database accessed | Notify customers per breach notification policy |
| P0 not resolved in 30 min | Invoke break-glass role (see [break-glass-procedure.md](break-glass-procedure.md)) |

---

## Post-Incident Requirements

- [ ] AWS Support case opened if account-level compromise suspected
- [ ] Incident report filed within 72 hours (required for HIPAA/GDPR)
- [ ] Security Hub finding status set to `RESOLVED` with notes
- [ ] AWS Config timeline reviewed for configuration changes before incident
- [ ] Corrective action item created in issue tracker
