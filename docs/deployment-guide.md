# FORGE Deployment Guide

This guide walks through deploying FORGE in four phases. Each phase is
independently applicable; you can stop after Phase 1 and still achieve
meaningful compliance improvements.

---

## Prerequisites

| Requirement | Version / Details |
|------------|------------------|
| Terraform | >= 1.5.0 |
| AWS CLI | >= 2.15 |
| Python | >= 3.12 (for remediation Lambdas and tests) |
| Go | >= 1.21 (for Terratest, optional) |
| AWS Account | Management account with Organizations enabled |
| IAM Permissions | `AdministratorAccess` on management account for initial bootstrap |
| Git | For cloning and pre-commit hooks |
| pre-commit | `pip install pre-commit` |

---

## Phase 0 — Repository Setup

```bash
git clone https://github.com/your-org/forge.git
cd forge

# Install pre-commit hooks (runs Checkov, Bandit, terraform fmt on every commit)
pip install pre-commit
pre-commit install

# Configure AWS credentials (management account)
aws configure --profile forge-bootstrap
export AWS_PROFILE=forge-bootstrap
```

---

## Phase 1 — Foundation Bootstrap (~20 min)

Deploy the organization structure, SCPs, KMS keys, and centralized logging.
**This is the most critical phase** — it establishes preventive guardrails.

> **Existing AWS Organization?** If your management account is already in an AWS Organization,
> import it into Terraform state before running `apply`, otherwise the plan will fail with
> `AlreadyInOrganizationException`:
> ```bash
> ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
> terraform import module.organization.aws_organizations_organization.this "$ORG_ID"
> ```
> Terraform will then reconcile the existing organization (adding any missing service principals
> or policy types) instead of trying to create a new one.

```bash
cd examples/baseline-regulated   # or your environment folder

# 1. Copy and populate variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars          # Fill in account emails, org_prefix, domain_name

# 2. Initialize Terraform
terraform init

# 3. Preview — pay close attention to SCP and KMS resources
terraform plan -out=phase1.out -target=module.organization \
  -target=module.scp -target=module.kms -target=module.logging

# 4. Apply
terraform apply phase1.out
```

After Phase 1, verify:

```bash
# SCPs are attached
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[*].Name'

# CloudTrail is running
aws cloudtrail describe-trails --query 'trailList[*].Name'

# KMS keys exist
aws kms list-aliases --query 'Aliases[?starts_with(AliasName, `alias/forge`)]'
```

---

## Phase 2 — Network and Identity (~15 min)

> **IAM Identity Center required.** The `sso` module reads the SSO instance via a data source.
> If IAM Identity Center has not been enabled in your management account, enable it before
> applying this phase:
> 1. Retrieve the dedicated KMS key ARN from Phase 1 output:
>    ```bash
>    terraform output -json kms_key_arns | jq -r '.identity_center'
>    ```
> 2. AWS Console → **IAM Identity Center** → **Enable**
> 3. When prompted for a KMS key, select **Customer managed key** and paste the ARN above.
> 4. Wait ~30 seconds for the instance to become available, then proceed.

> **RAM organization sharing required.** Cloud WAN shares the core network across accounts via AWS RAM.
> Enable organization sharing once before applying (idempotent — safe to run multiple times):
> ```bash
> aws ram enable-sharing-with-aws-organization
> ```

```bash
# 1. Preview — pay close attention to SCP and KMS resources
terraform plan -out=phase2.out \
  -target=module.vpc -target=module.transit_gateway -target=module.dns \
  -target=module.cloud_wan -target=module.vpc_peering \
  -target=module.iam_baseline -target=module.mfa_enforcement -target=module.sso \
  -target=module.tls_enforcement

# 2. Apply
terraform apply phase2.out
```

After Phase 2, verify:

```bash
# VPC exists with expected subnets
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*forge*" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock}'

# Cloud WAN Global Network is active
aws networkmanager describe-global-networks \
  --query 'GlobalNetworks[?contains(Tags[?Key==`Name`].Value|[0], `forge`)].{ID:GlobalNetworkId,State:State}'

# Cloud WAN Core Network is AVAILABLE
aws networkmanager list-core-networks \
  --query 'CoreNetworks[*].{ID:CoreNetworkId,State:State}'

# VPC Peering connections are active (if enabled)
aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Name,Values=*forge*" \
  --query 'VpcPeeringConnections[*].{ID:VpcPeeringConnectionId,Status:Status.Code}'

# IAM Access Analyzer is active
aws accessanalyzer list-analyzers --query 'analyzers[*].{Name:name,Status:status}'

# MFA SCP is attached to root
aws organizations list-policies-for-target \
  --target-id $(aws organizations list-roots --query 'Roots[0].Id' --output text) \
  --filter SERVICE_CONTROL_POLICY --query 'Policies[*].Name'
```

---

## Phase 3 — Security Detectives (~10 min)

```bash
terraform plan -out=phase3.out \
  -target=module.security_alerts -target=module.security_hub \
  -target=module.inspector -target=module.config_rules

terraform apply phase3.out
```

After Phase 3, verify:

```bash
# GuardDuty is enabled in this region
aws guardduty list-detectors --query 'DetectorIds'

# Security Hub is enabled with standards
aws securityhub describe-hub --query 'HubArn'
aws securityhub get-enabled-standards \
  --query 'StandardsSubscriptions[*].StandardsArn'

# Config recorder is running
aws configservice describe-configuration-recorder-status \
  --query 'ConfigurationRecordersStatus[*].{Name:name,Recording:recording}'

# Check first FORGE Config rules exist
aws configservice describe-config-rules \
  --query 'ConfigRules[?starts_with(ConfigRuleName, `FORGE`)].ConfigRuleName' \
  | head -10
```

---

## Phase 4 — Remediation Lambdas (~5 min)

```bash
terraform apply   # Apply the remaining remediation modules

# Or target all at once:
terraform plan -out=phase4.out \
  -target=module.remediate_s3 -target=module.remediate_mfa \
  -target=module.remediate_ebs -target=module.remediate_sg \
  -target=module.remediate_rds

terraform apply phase4.out
```

After Phase 4, verify:

```bash
# All FORGE Lambda functions deployed
aws lambda list-functions \
  --query 'Functions[?starts_with(FunctionName, `forge-remediate`)].FunctionName'

# Test S3 remediation: create a public bucket and watch it get blocked
BUCKET="forge-test-$(date +%s)"
aws s3api create-bucket --bucket "$BUCKET" --region us-east-1

# Remove public access block to trigger Config rule FORGE-S3-001 (change-triggered)
aws s3api delete-public-access-block --bucket "$BUCKET"

# Optionally force immediate Config evaluation (otherwise triggers within ~1-2 min)
aws configservice start-config-rules-evaluation \
  --config-rule-names FORGE-S3-001 --region us-east-1

# Watch Lambda logs (log group created on first invocation — wait ~15s)
LOG_GROUP="/aws/lambda/forge-remediate-s3-block-public-access"
aws logs tail "$LOG_GROUP" --follow --format short

# Verify public access block was re-applied
aws s3api get-public-access-block --bucket "$BUCKET"

# Check Lambda invocation metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=forge-remediate-s3-block-public-access \
  --start-time "$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 300 --statistics Sum \
  --query 'Datapoints[*].Sum'

# Clean up test bucket
aws s3api delete-bucket --bucket "$BUCKET" --region us-east-1
```

---

## Final Wire-Up — SNS Alarm Integration

After all four phases, run a full apply (no targets) to connect the GuardDuty/Security Hub
SNS topic from Phase 3 into the root login CloudWatch alarm created in Phase 1:

```bash
cd examples/baseline-regulated
terraform apply
```

This resolves the cross-module dependency between `module.security_alerts` (SNS topic) and
`module.logging` (CloudWatch alarm action). The plan should show only an in-place update to
the alarm — no resources will be destroyed.

Verify the alarm is wired:

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix forge \
  --query 'MetricAlarms[*].{Name:AlarmName,Actions:AlarmActions}'
```

---

## Validating Compliance Coverage

After all phases, run the compliance tests:

```bash
cd tests/compliance
pip install -r requirements.txt
python -m pytest test_forge_controls.py -v
```

Generate a full evidence report (requires AWS CLI jq):

```bash
aws securityhub get-findings \
  --filters '{"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}]}' \
  --query 'Findings[*].{Title:Title,Severity:Severity.Label,Status:Compliance.Status}' \
  | jq '.[] | select(.Status != "PASSED")'
```

---

## Choosing an Example

FORGE ships three reference deployments. **Pick one** — they are independent stacks, not layers.
Deploying more than one into the same AWS account will create duplicate resources (two Config
recorders, two GuardDuty detectors, duplicate KMS keys, etc.).

| Example | Profile | Standards | When to use |
|---------|---------|-----------|-------------|
| `baseline-regulated` | Seed-stage / early startup | NIST 800-53, SOC 2 | First deployment, proof-of-concept, or single-account environments |
| `growth-stage` | 50–500 employees, regional bank / mid-tier finserv | SOC 2 Type II + HIPAA | Multi-region active-active topology, SCIM IdP integration, WAFv2, Macie |
| `regulated-enterprise` | 500+ employees, FFIEC CAT / HIPAA / FedRAMP Moderate | FFIEC + HIPAA + NIST 800-53 | Network Firewall, Audit Manager, centralized SIEM bus, WORM backup vault |

> **Upgrading between profiles?** Do not apply a larger profile on top of an existing one.
> Follow the [teardown procedure](#teardown) to cleanly remove the current deployment first,
> then deploy the new profile from scratch. Importing existing AWS resources (VPC, KMS keys,
> CloudTrail) into the new state is supported — see the import notes in each example's `README.md`.

### growth-stage

```bash
cd examples/growth-stage
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

terraform init

# Import existing organization if one already exists
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
terraform import module.organization.aws_organizations_organization.this "$ORG_ID"

terraform plan -out=plan.out
terraform apply plan.out
```

Additional prerequisites:
- **IAM Identity Center** must be enabled before apply (see Phase 2 notes above).
- **RAM organization sharing** must be enabled: `aws ram enable-sharing-with-aws-organization`
- Provide `secondary_region` (default `us-west-2`) — a VPC will be created there.
- Optionally provide `scim_endpoint_url` + `scim_access_token_secret_arn` for IdP provisioning.
- Optionally provide `waf_alb_arn` to associate the WAFv2 WebACL with an existing ALB.

### regulated-enterprise

```bash
cd examples/regulated-enterprise
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

terraform init

ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
terraform import module.organization.aws_organizations_organization.this "$ORG_ID"

terraform plan -out=plan.out
terraform apply plan.out
```

Additional prerequisites:
- All growth-stage prerequisites apply.
- Pre-allocate `firewall_subnet_cidrs` — one `/28` per AZ within your VPC CIDR, not overlapping
  app or data subnets (e.g. `["10.0.48.0/28", "10.0.48.16/28", "10.0.48.32/28"]`).
- Provide `siem_event_bus_arn` if forwarding findings to an existing centralized SIEM bus.

---

## Teardown

Some AWS resources managed by FORGE **must not be auto-deleted** by Terraform and require
manual cleanup. Remove them from state first, then destroy the rest.

### Break-Glass Required Operations

FORGE intentionally protects certain resources from routine deletion. For these actions,
use the break-glass role documented in [runbooks/break-glass-procedure.md](runbooks/break-glass-procedure.md).

Before teardown or emergency cleanup:

```bash
# 1. Verify your trusted principal exists (replace as needed)
aws iam get-user --user-name security-admin

# 2. Get break-glass role ARN from Terraform outputs
terraform output break_glass_role_arn

# 3. Assume break-glass role (see full runbook for MFA/session naming requirements)
aws sts assume-role \
  --role-arn "$(terraform output -raw break_glass_role_arn)" \
  --role-session-name "break-glass-$(date +%Y%m%d-%H%M%S)-ops"
```

Protected resources by profile:

| Profile | Protected resource | Why protected | Management approach |
|---------|--------------------|---------------|---------------------|
| All profiles | `module.organization.aws_organizations_organization.this` | AWS account may already be in an Organization; cannot be deleted while member accounts exist | Import before apply; remove from state before destroy; delete organization manually after removing member accounts |
| All profiles | `module.kms.*` | Key policy denies `kms:ScheduleKeyDeletion` for non-break-glass principals | Remove from state before destroy; schedule key deletion manually with break-glass |
| All profiles | Log archive/Object Lock resources in `module.logging` | Immutable retention is intentional for compliance evidence | If destroy fails, remove from state and perform manual cleanup after retention requirements are met |
| Regulated enterprise | `aws_networkfirewall_firewall.main` | `delete_protection` defaults to `true` | Set `enable_firewall_delete_protection = false`, apply, then destroy |
| Regulated enterprise | `aws_backup_vault_lock_configuration.primary` | Vault Lock is WORM and can become immutable | Remove lock only during changeable window; otherwise wait for retention window to expire |

### Resources to remove from state (do not auto-delete)

| Resource | Why | Manual cleanup |
|----------|-----|----------------|
| `aws_organizations_organization` | Cannot delete while member accounts exist | Remove/close all member accounts first, then delete via console |
| All KMS keys (`module.kms.*`) | Key policies contain explicit deny on `kms:ScheduleKeyDeletion` | Update key policy in console, then schedule 7-day deletion |
| IAM automation users (e.g. `FORGEAutomation`) | Access keys may be in use elsewhere | Delete via IAM console when safe |

### Step-by-step teardown

```bash
cd examples/<env>   # the environment you want to destroy

# 1. Remove the Organization from state (leave it in AWS)
terraform state rm module.organization.aws_organizations_organization.this

# 2. Remove all KMS resources from state (leave keys in AWS)
terraform state rm $(terraform state list | grep 'module.kms')

# 3. Check for any IAM users and remove from state
terraform state list | grep 'aws_iam_user'
# For each result:
# terraform state rm <address>

# 4. Destroy everything remaining
terraform plan -destroy -out=destroy.out
terraform apply destroy.out
```

If `terraform destroy` errors on a specific resource (e.g. an S3 bucket with object lock, an
SCP with dependent attachments), remove that resource from state and re-run:

```bash
terraform state rm <failing-resource-address>
terraform apply destroy.out   # re-run the same plan
```

### Manual cleanup after destroy

**KMS keys:**
```bash
# For each key — first update the key policy to remove the explicit deny on
# kms:ScheduleKeyDeletion (console: KMS → Key → Key policy → Edit), then:
aws kms schedule-key-deletion \
  --key-id <key-id> \
  --pending-window-in-days 7
```

**AWS Organization:**
1. Close or remove all member accounts (AWS Console → Organizations → Accounts).
2. Once no member accounts remain: Organizations → Settings → Delete organization.

**SCPs:** SCPs are automatically detached and deleted by `terraform destroy`. If the destroy
fails mid-way, detach SCPs manually before retrying:
```bash
aws organizations detach-policy --policy-id <scp-id> \
  --target-id $(aws organizations list-roots --query 'Roots[0].Id' --output text)
```

**Regulated-enterprise firewall delete protection:**
```bash
# In examples/regulated-enterprise/terraform.tfvars:
# enable_firewall_delete_protection = false

terraform apply -target=aws_networkfirewall_firewall.main
terraform plan -destroy -out=destroy.out
terraform apply destroy.out
```

**Regulated-enterprise backup vault lock:**
```bash
# Works only while the lock is still changeable
aws backup delete-backup-vault-lock-configuration \
  --backup-vault-name <primary-vault-name>

# If the lock is already immutable, keep vault resources out of Terraform destroy
terraform state rm aws_backup_vault_lock_configuration.primary
terraform state rm aws_backup_vault.primary
terraform state rm aws_backup_vault.secondary
```

---


1. Review [CHANGELOG.md](../CHANGELOG.md) for breaking changes.
2. Run `terraform plan` — review any destroy/replace actions carefully.
3. Update SCPs incrementally: apply to Sandbox OU first, then promote.
4. Run full compliance tests after every upgrade.

---

## Rollback

FORGE uses Terraform state for all resources. To roll back:

```bash
# Revert to a previous state snapshot (if using S3 backend)
aws s3 cp s3://your-state-bucket/forge/.../terraform.tfstate.backup ./terraform.tfstate
terraform apply -refresh=false

# Remove a specific resource if it causes issues
terraform state rm module.security_alerts.aws_guardduty_detector.this
```

> **Note:** SCPs cannot be removed while they have dependent attachments.
> Always detach from OUs/accounts before destroying SCP resources.
