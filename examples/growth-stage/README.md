# FORGE — Example: Growth-Stage Company

Extends [baseline-regulated](../baseline-regulated/) for regional banks and
mid-tier financial services institutions targeting **SOC 2 Type II + HIPAA**
dual-standard compliance on AWS.

## What's included

| Component | Details |
|-----------|---------|
| **Multi-region active-active VPCs** | Primary + secondary region VPCs attached to a shared Cloud WAN backbone (`vpc_primary`, `vpc_secondary`) |
| **Separate production and non-production OUs** | SCPs applied to both `ou_workloads_prod` and `ou_workloads_nonprod` |
| **IAM Identity Center with SCIM** | Automated user/group provisioning from Okta, Entra ID, or JumpCloud; attribute mapping for `email` and `department` |
| **AWS Config Aggregator** | Organization-wide aggregator consolidates Config findings from all accounts into a single compliance view |
| **Amazon Macie** | Weekly S3 sensitive-data classification jobs for PII, PCI, and PHI discovery (HIPAA §164.312) |
| **WAFv2 — OWASP Top 10 managed rule sets** | Common Rule Set, Known Bad Inputs, and SQLi rules applied regionally; optional ALB association |
| **All baseline-regulated controls** | Foundation, network, identity, security, encryption, and remediation modules inherited |

## Prerequisites

1. An AWS management account with Organizations enabled.
2. Terraform >= 1.5.0 installed locally.
3. AWS credentials with `AdministratorAccess` on the management account.
4. A registered domain name for ACM certificate validation.
5. *(Optional)* An existing SCIM 2.0 endpoint from your identity provider.

## Quick Start

```bash
# 1. Navigate to this example
cd examples/growth-stage

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 3. Initialize
terraform init

# 4. Import existing AWS Organization — REQUIRED before first apply
#    Every AWS account belongs to an organization. Terraform will error with
#    AlreadyInOrganizationException if you skip this step.
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
terraform import module.organization.aws_organizations_organization.this "$ORG_ID"
```

```bash
# 5. Plan and apply
terraform plan -out=plan.out
terraform apply plan.out
```

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | Primary deployment region | `us-east-1` |
| `secondary_region` | Secondary region for active-active topology | `us-west-2` |
| `vpc_cidr` | Primary VPC CIDR | `10.0.0.0/16` |
| `secondary_vpc_cidr` | Secondary VPC CIDR (must not overlap) | `10.1.0.0/16` |
| `az_count` | AZs per region (2–3) | `3` |
| `enable_macie` | Enable Amazon Macie sensitive-data discovery | `true` |
| `scim_endpoint_url` | SCIM 2.0 endpoint URL (optional) | `""` |
| `waf_alb_arn` | ALB ARN for WAFv2 association (optional) | `""` |

## Key Outputs

| Output | Description |
|--------|-------------|
| `primary_vpc_id` / `secondary_vpc_id` | VPC IDs for both regions |
| `primary_private_app_subnet_ids` | Application-tier subnet IDs, primary region |
| `secondary_private_app_subnet_ids` | Application-tier subnet IDs, secondary region |
| `break_glass_role_arn` | Emergency access role ARN |
| `sso_instance_arn` | IAM Identity Center instance ARN |
| `config_aggregator_arn` | Organization-wide Config aggregator ARN |
| `waf_web_acl_arn` | Regional WAFv2 WebACL ARN |
| `kms_key_arns` | Map of KMS key domain → ARN |

## Protected Resources and Break-Glass Operations

Growth-stage inherits all baseline protected resources and adds multi-region dependencies.
Use this runbook before emergency changes:
[docs/runbooks/break-glass-procedure.md](../../docs/runbooks/break-glass-procedure.md).

Pre-flight checks (prevents the most common apply failures):

```bash
cd examples/growth-stage

# Ensure the break-glass trusted principal in terraform.tfvars actually exists
aws iam get-user --user-name security-admin

# Import existing Organization if present
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
terraform import module.organization.aws_organizations_organization.this "$ORG_ID"
```

If KMS aliases already exist (for example after partial applies), import them instead of recreating:

```bash
terraform import 'module.kms.aws_kms_alias.this["cloudtrail"]' alias/forge-growth-cloudtrail
terraform import 'module.kms.aws_kms_alias.this["ebs"]' alias/forge-growth-ebs
terraform import 'module.kms.aws_kms_alias.this["guardduty"]' alias/forge-growth-guardduty
terraform import 'module.kms.aws_kms_alias.this["identity_center"]' alias/forge-growth-identity_center
terraform import 'module.kms.aws_kms_alias.this["rds"]' alias/forge-growth-rds
terraform import 'module.kms.aws_kms_alias.this["s3_logs"]' alias/forge-growth-s3_logs
terraform import 'module.kms.aws_kms_alias.this["secrets"]' alias/forge-growth-secrets
terraform import 'module.kms.aws_kms_alias.this["sns"]' alias/forge-growth-sns
```

Teardown pattern for protected resources:

```bash
terraform state rm module.organization.aws_organizations_organization.this
terraform state rm $(terraform state list | grep 'module.kms')

# If immutable logging resources block destroy
terraform state list | grep 'module.logging' | grep -E 's3_bucket|object_lock|lifecycle'
# terraform state rm <each-matching-address>

terraform plan -destroy -out=destroy.out
terraform apply destroy.out
```

## Compliance Coverage

- **SOC 2 Type II**: CC1–CC9, A1, C1, PI1
- **HIPAA Security Rule**: 164.308, 164.310, 164.312 (Macie covers §164.312(a)(2)(iv) sensitive-data discovery)
- **NIST SP 800-53 Rev 5**: AC, AU, CA, CM, IA, IR, RA, SC, SI families
- **FFIEC CAT**: All 5 domains at Baseline → Evolving maturity pathway

## Next Step

For large enterprises (500+ employees) under FFIEC CAT or HIPAA mandates, see
[`examples/regulated-enterprise/`](../regulated-enterprise/).
