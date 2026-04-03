# FORGE — Example: Regulated Enterprise

Extends [growth-stage](../growth-stage/) for large enterprises (500+ employees)
operating under **FFIEC CAT** (banking/fintech) and/or **HIPAA** (healthcare)
mandates, with FedRAMP Moderate baseline alignment.

## What's included

| Component | Details |
|-----------|---------|
| **AWS Network Firewall** | Stateful east-west and north-south packet inspection; dedicated `/28` firewall subnets per AZ; flow + alert logs to CloudWatch |
| **AWS Audit Manager** | Custom FORGE assessment framework with controls for IAM MFA, access key rotation, S3 encryption, and RDS encryption; automated evidence collection to S3 |
| **AWS Backup — centralized vault** | Daily + weekly backup plans with cross-region copy to secondary vault; Backup Vault Lock (WORM) for HIPAA-compliant immutable retention |
| **Centralized SIEM EventBridge bus** | Cross-account event bus accepting `PutEvents` from all Organization accounts; GuardDuty findings ≥ severity 7 forwarded automatically |
| **NIST 800-53 Rev 5 conformance pack** | AWS Config conformance pack for FedRAMP Moderate alignment (`access-keys-rotated` and extensible rule set) |
| **Amazon Macie** | 15-minute finding publication frequency; weekly S3 classification jobs for PHI/PCI discovery |
| **All growth-stage controls** | Multi-region VPCs, Config Aggregator, WAFv2, SCIM, IAM Identity Center, and all baseline modules inherited |

## Prerequisites

1. An AWS management account with Organizations enabled.
2. Terraform >= 1.5.0 installed locally.
3. AWS credentials with `AdministratorAccess` on the management account.
4. A registered domain name for ACM certificate validation.
5. Firewall subnet CIDRs pre-allocated within your VPC CIDR (`firewall_subnet_cidrs`).

## Quick Start

```bash
# 1. Navigate to this example
cd examples/regulated-enterprise

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 3. Initialize
terraform init

# 4. Import existing AWS Organization — REQUIRED before first apply
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
terraform import module.organization.aws_organizations_organization.this "$ORG_ID"

# 5. Plan and apply
terraform plan -out=plan.out
terraform apply plan.out
```

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `compliance_frameworks` | Frameworks in scope (tags + Audit Manager naming) | `["hipaa", "ffiec-cat"]` |
| `firewall_subnet_cidrs` | `/28` CIDRs for Network Firewall endpoints (one per AZ) | `["10.0.3.0/28", ...]` |
| `enable_firewall_delete_protection` | Protect firewall from accidental deletion | `true` |
| `enable_audit_manager` | Deploy Audit Manager framework and assessment | `true` |
| `enable_backup_vault_lock` | Enable WORM Vault Lock on backup vaults | `true` |
| `backup_min_retention_days` | Vault Lock retention lower bound | `7` |
| `backup_max_retention_days` | Vault Lock retention upper bound (HIPAA min = 6 years) | `3650` |
| `enable_siem_event_bus` | Create cross-account EventBridge SIEM bus | `true` |

## Key Outputs

| Output | Description |
|--------|-------------|
| `network_firewall_arn` | ARN of the AWS Network Firewall |
| `firewall_subnet_ids` | Subnet IDs for firewall endpoints |
| `primary_backup_vault_arn` | Primary-region Backup vault ARN |
| `secondary_backup_vault_arn` | Secondary-region Backup vault ARN (cross-region copy target) |
| `audit_manager_framework_arn` | FORGE Audit Manager custom framework ARN |
| `audit_manager_assessment_arn` | Audit Manager assessment ARN |
| `siem_event_bus_arn` | Cross-account EventBridge SIEM bus ARN |
| `nist_conformance_pack_arn` | NIST 800-53 Rev 5 Config conformance pack ARN |

## Compliance Coverage

- **FFIEC CAT**: All 5 domains; Baseline → Intermediate maturity pathway with Audit Manager evidence
- **HIPAA Security Rule**: 164.308, 164.310, 164.312 — Backup Vault Lock satisfies §164.312(c)(2) integrity; Macie satisfies §164.312(a)(2)(iv)
- **NIST SP 800-53 Rev 5**: Full AC, AU, CA, CM, IA, IR, RA, SC, SI families + conformance pack
- **FedRAMP Moderate**: Baseline alignment via NIST 800-53 Rev 5 conformance pack and Network Firewall east-west inspection
- **SOC 2 Type II**: CC1–CC9 inherited from growth-stage

## Architecture Notes

### Network Firewall Placement

Firewall endpoints are deployed into dedicated `/28` subnets distinct from the
application and data tiers. Traffic routing to redirect north-south and east-west
flows through firewall endpoints must be configured in your VPC route tables after
deployment. Refer to the [AWS Network Firewall deployment guide](https://docs.aws.amazon.com/network-firewall/latest/developerguide/arch-two-zone-igw.html)
for route table configuration patterns.

### Backup Vault Lock Warning

Once `backup_vault_lock_changeable_days` elapses (default: 3 days), the Vault Lock
configuration becomes **immutable and irreversible**. Setting `enable_backup_vault_lock = true`
is appropriate for production; verify `backup_min_retention_days` before applying.
Set `backup_vault_lock_changeable_days = 0` only when certain — this takes effect immediately.

### SIEM Integration

The cross-account EventBridge bus accepts `PutEvents` from any principal in the AWS
Organization. Connect your SIEM (Splunk, Microsoft Sentinel, Sumo Logic) as an
EventBridge API destination or Lambda target on `${var.org_prefix}-siem-event-bus`.

## Protected Resources and Break-Glass Operations

This profile includes all baseline/growth protected resources plus additional
enterprise-grade deletion guards.

Use break-glass for emergency teardown actions:
[docs/runbooks/break-glass-procedure.md](../../docs/runbooks/break-glass-procedure.md).

### Resources that commonly block Terraform destroy

| Resource | Why it blocks destroy | How to manage safely |
|----------|------------------------|----------------------|
| `module.organization.aws_organizations_organization.this` | Cannot be deleted with member accounts | Remove from state; delete organization manually later |
| `module.kms.*` | KMS policy denies `kms:ScheduleKeyDeletion` to non-break-glass principals | Remove from state; schedule deletion manually |
| `aws_networkfirewall_firewall.main` | `delete_protection` defaults to `true` | Set `enable_firewall_delete_protection = false`, apply, then destroy |
| `aws_backup_vault_lock_configuration.primary` | Vault Lock can become immutable after changeable window | Delete lock only while changeable; otherwise retain vault and remove from state |

### Teardown sequence (recommended)

```bash
cd examples/regulated-enterprise

# 1) Disable firewall delete protection in terraform.tfvars
# enable_firewall_delete_protection = false
terraform apply -target=aws_networkfirewall_firewall.main

# 2) If Vault Lock is still changeable, remove lock first
aws backup delete-backup-vault-lock-configuration \
  --backup-vault-name <primary-vault-name>

# 3) Remove protected resources from Terraform state
terraform state rm module.organization.aws_organizations_organization.this
terraform state rm $(terraform state list | grep 'module.kms')
terraform state rm aws_backup_vault_lock_configuration.primary

# If lock is immutable, keep vault resources out of Terraform destroy
terraform state rm aws_backup_vault.primary
terraform state rm aws_backup_vault.secondary

# 4) Destroy the remainder
terraform plan -destroy -out=destroy.out
terraform apply destroy.out
```

After destroy, perform manual cleanup under break-glass session:

- KMS keys: update policy if needed, then `aws kms schedule-key-deletion`.
- Organization: remove/close member accounts, then delete organization.
- Backup vaults: if lock is immutable, wait for retention and recovery-point constraints before deletion.

