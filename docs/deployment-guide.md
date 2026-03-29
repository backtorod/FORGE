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
aws securityhub list-enabled-standards \
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
aws s3api create-bucket --bucket forge-test-$(date +%s) --region us-east-1
# Within ~60 seconds, the Lambda should block public access
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

## Upgrading FORGE

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
