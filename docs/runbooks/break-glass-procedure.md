# Runbook: Break-Glass Procedure

**Control Reference:** FORGE-IAM-005
**Terraform Module:** `modules/identity/iam-baseline`
**Last Reviewed:** 2026-01-01

---

## Purpose

The FORGE break-glass role (`forge-break-glass-*`) provides emergency
`AdministratorAccess` for situations where normal access paths are
unavailable. Use of this role is a **high-impact, audited event** that
triggers an immediate CloudWatch alarm and SNS alert.

**Assume this role only when:**
- A P0/P1 incident requires permissions that exceed your normal role.
- IAM Identity Center is unavailable or misconfigured.
- An active security incident requires immediate containment.

---

## Pre-Conditions

- [ ] You are named in `var.break_glass_trusted_arns` in the Terraform deployment.
- [ ] Your AWS IAM user or role has MFA configured.
- [ ] Your MFA token was issued within the last **15 minutes** (session condition enforced).
- [ ] Incident ticket has been opened (link below).
- [ ] Your manager or on-call security lead has been notified.

---

## Procedure

### Step 1 — Open an Incident Ticket

Before assuming the role, document:

- **Date/Time (UTC):**
- **Incident ID:**
- **Requestor:**
- **Justification:**
- **Expected duration:**
- **Actions planned:**

### Step 2 — Assume the Break-Glass Role

```bash
# Replace ACCOUNT_ID with the target account number
aws sts assume-role \
  --role-arn "arn:aws:iam::ACCOUNT_ID:role/forge-break-glass-admin" \
  --role-session-name "break-glass-$(date +%Y%m%d-%H%M%S)-YOUR_NAME" \
  --serial-number "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:mfa/YOUR_MFA_DEVICE" \
  --token-code "YOUR_MFA_TOKEN" \
  --duration-seconds 3600 \
  --profile your-normal-profile

# Export the temporary credentials (or use --profile break-glass)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

> The session is limited to **1 hour** and MFA age must be < 15 minutes.
> The session name must start with "break-glass-" to satisfy the role policy.

### Step 3 — Perform Required Actions

Perform only the minimum actions necessary. All API calls are logged to
CloudTrail in the immutable S3 bucket under the session name
`break-glass-TIMESTAMP-NAME`.

### Step 4 — Exit and Rotate

```bash
# Unset temporary credentials immediately after use
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

If any permanent credentials were created during the session, rotate or
delete them before closing the incident.

### Step 5 — Post-Incident Review

Within 24 hours:

1. Retrieve CloudTrail events for the session:
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=Username,AttributeValue="break-glass-TIMESTAMP-YOUR_NAME" \
     --start-time "2026-01-01T00:00:00Z" \
     --query 'Events[*].{Time:EventTime,Event:EventName,Resource:Resources}'
   ```
2. Document all actions taken in the incident ticket.
3. Determine root cause of why break-glass was needed.
4. File a corrective action item if a preventable condition caused the need.

---

## Alerts Generated

| Alert | Destination | Trigger |
|-------|-------------|---------|
| CloudWatch Alarm | SNS → security team | `AssumeRole` on `forge-break-glass-*` |
| CloudTrail Event | Immutable S3 / SIEM | All API calls during session |
| Security Hub Finding | Audit account | IAM unusual activity |

---

## Contacts

| Role | When to Contact |
|------|----------------|
| Security Operations | Immediately upon role assumption |
| Engineering Manager | If production changes are necessary |
| Legal / Compliance | If PHI or PCI data may be involved |
