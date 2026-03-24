# Runbook: RDS Encryption Remediation

**Control Reference:** FORGE-RDS-001
**Trigger:** `remediation/rds/encrypt-rds` Lambda finds unencrypted DB instance
**Last Reviewed:** 2026-01-01

---

## Background

AWS RDS **does not support enabling encryption on a running instance**.
The only path to encrypting an unencrypted RDS instance is:

1. Create an unencrypted snapshot of the existing instance.
2. Copy the snapshot, specifying a KMS key — this creates an encrypted copy.
3. Restore a new DB instance from the encrypted snapshot.
4. Promote the new instance (update DNS / connection strings).
5. Delete the old unencrypted instance after validation.

This is a **destructive and potentially disruptive** process. The FORGE
Lambda remediation module intentionally **does not automate** this to avoid
unplanned production outages. A human must perform this runbook.

**Estimated downtime:** Zero (blue-green promotion) to several minutes
(DNS propagation), depending on your application architecture.

---

## Pre-Conditions

- [ ] You have received the FORGE-RDS-001 SNS alert.
- [ ] An incident ticket has been opened.
- [ ] You have obtained DB instance identifier from the alert.
- [ ] A maintenance window has been scheduled and communicated to stakeholders.
- [ ] You have `AdministratorAccess` or targeted RDS + KMS permissions.
- [ ] The `forge-rds` KMS key ARN is available (see Terraform outputs).

---

## Step 1 — Identify the Target Instance

```bash
# Get the unencrypted instance details
DB_IDENTIFIER="your-db-instance-id"   # From the SNS alert

aws rds describe-db-instances \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query 'DBInstances[0].{
    ID:DBInstanceIdentifier,
    Class:DBInstanceClass,
    Engine:Engine,
    EngineVersion:EngineVersion,
    Storage:AllocatedStorage,
    MultiAZ:MultiAZ,
    Encrypted:StorageEncrypted,
    Endpoint:Endpoint.Address,
    SubnetGroup:DBSubnetGroup.DBSubnetGroupName,
    ParameterGroup:DBParameterGroups[0].DBParameterGroupName,
    OptionGroup:OptionGroupMemberships[0].OptionGroupName,
    VPC:DBSubnetGroup.VpcId
  }'
```

---

## Step 2 — Create a Final Snapshot

```bash
SNAPSHOT_ID="forge-encrypt-migration-$(date +%Y%m%d-%H%M%S)"

aws rds create-db-snapshot \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --db-snapshot-identifier "$SNAPSHOT_ID"

# Wait for snapshot to complete (~5-30 min depending on DB size)
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$SNAPSHOT_ID"

echo "Snapshot $SNAPSHOT_ID is ready"
```

---

## Step 3 — Copy Snapshot with Encryption

```bash
# Get KMS key ARN from Terraform output
KMS_KEY_ARN="arn:aws:kms:us-east-1:ACCOUNT_ID:key/YOUR-FORGE-RDS-KEY-ID"

ENCRYPTED_SNAPSHOT_ID="${SNAPSHOT_ID}-encrypted"

aws rds copy-db-snapshot \
  --source-db-snapshot-identifier "$SNAPSHOT_ID" \
  --target-db-snapshot-identifier "$ENCRYPTED_SNAPSHOT_ID" \
  --kms-key-id "$KMS_KEY_ARN" \
  --copy-tags

# Wait for encrypted snapshot copy to complete
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$ENCRYPTED_SNAPSHOT_ID"

# Verify it is encrypted
aws rds describe-db-snapshots \
  --db-snapshot-identifier "$ENCRYPTED_SNAPSHOT_ID" \
  --query 'DBSnapshots[0].{Encrypted:Encrypted,KmsKeyId:KmsKeyId}'
```

---

## Step 4 — Restore New Encrypted Instance

```bash
NEW_DB_IDENTIFIER="${DB_IDENTIFIER}-encrypted"

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "$NEW_DB_IDENTIFIER" \
  --db-snapshot-identifier "$ENCRYPTED_SNAPSHOT_ID" \
  --db-instance-class "SAME_CLASS_AS_ORIGINAL" \
  --no-multi-az   # Set --multi-az if original was Multi-AZ
  --db-subnet-group-name "SAME_SUBNET_GROUP_AS_ORIGINAL" \
  --publicly-accessible   # false unless original was public
  --vpc-security-group-ids "SAME_SG_IDS_AS_ORIGINAL" \
  --tags Key=FORGE_Control,Value=FORGE-RDS-001 \
         Key=EncryptionMigration,Value=true \
         Key=MigratedFrom,Value="$DB_IDENTIFIER"

# Wait for the new instance to be available (~10-30 min)
aws rds wait db-instance-available \
  --db-instance-identifier "$NEW_DB_IDENTIFIER"

echo "New encrypted instance $NEW_DB_IDENTIFIER is ready"
```

---

## Step 5 — Validate the New Instance

```bash
# 1. Confirm encryption is enabled
aws rds describe-db-instances \
  --db-instance-identifier "$NEW_DB_IDENTIFIER" \
  --query 'DBInstances[0].{Encrypted:StorageEncrypted,KmsKeyId:KmsKeyId}'

# 2. Get connection endpoint
aws rds describe-db-instances \
  --db-instance-identifier "$NEW_DB_IDENTIFIER" \
  --query 'DBInstances[0].Endpoint.Address'

# 3. Test connectivity from your application environment
# (replace with your DB connection test command)
psql -h NEW_ENDPOINT -U admin -d your_database -c "SELECT 1;"
```

---

## Step 6 — Promote (Blue-Green Cutover)

Option A — **Route 53 CNAME** (recommended, zero downtime):

```bash
# Point your CNAME record to the new encrypted instance endpoint
# Update in your DNS hostedzone or Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "db.internal.example.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "NEW_ENDPOINT"}]
      }
    }]
  }'
```

Option B — **Direct connection string update** (application restart required):

Update `DATABASE_URL` / connection string in your application config/secrets
to point to the new endpoint.

---

## Step 7 — Decommission Old Instance

After **successful validation in production** (minimum 24-hour observation):

```bash
# Delete the old unencrypted instance (take a final snapshot first)
aws rds delete-db-instance \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --final-db-snapshot-identifier "${DB_IDENTIFIER}-final-before-delete"

# Clean up migration snapshots after 30 days
aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT_ID"
aws rds delete-db-snapshot --db-snapshot-identifier "$ENCRYPTED_SNAPSHOT_ID"
```

---

## Verification — Config Rule Should Now Pass

```bash
# Trigger re-evaluation of FORGE-RDS-001 for the new instance
aws configservice start-config-rules-evaluation \
  --config-rule-names FORGE-RDS-001

# Wait ~60 seconds, then check compliance
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name FORGE-RDS-001 \
  --compliance-types COMPLIANT \
  --query 'EvaluationResults[*].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId'
```

---

## Rollback

If the new encrypted instance has issues:

1. Revert DNS/connection string to point back to original DB.
2. **Do not delete** the original instance until the ticket is resolved.
3. Open a new incident P1 ticket for the migration failure.

---

## Estimated Effort

| Phase | Duration |
|-------|----------|
| Snapshot creation | 5–30 min (proportional to DB size) |
| Encrypted snapshot copy | 5–20 min |
| Restore new instance | 10–30 min |
| Validation | 15–60 min |
| Cutover + observation | 24 hours |
| **Total calendar time** | ~25 hours (most is waiting) |

---

## Related Controls

- **FORGE-RDS-002** — Multi-AZ enforcement (ensure new instance has MultiAZ: true in prod)
- **FORGE-KMS-001** — The `forge-rds` KMS key used for encryption must have rotation enabled
