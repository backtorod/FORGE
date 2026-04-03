# FORGE — Example: Baseline Regulated

This example deploys the full FORGE framework for a baseline regulated institution —
community banks, credit unions, or Fintech entities — targeting **SOC 2 Type II**
or **FFIEC CAT Baseline** maturity compliance on AWS.

## What's included

| Module | Purpose |
|--------|---------|
| `organization` | AWS Organizations, 5 OUs, 4 accounts |
| `scp` | 10 preventive guardrail policies |
| `kms` | 7-key hierarchy with annual rotation |
| `logging` | Immutable CloudTrail + VPC Flow Logs (7-year retention) |
| `vpc` | Three-tier VPC (public/app/data), Flow Logs, tight SGs |
| `transit_gateway` | Hub-and-spoke network topology |
| `cloud_wan` | AWS Cloud WAN org-wide backbone with 3 segments (workload / shared-services / inspection) |
| `vpc_peering` | Cross-region intra-account VPC peering (enabled via `enable_cross_region_peering`) |
| `dns` | Route 53 private zone + Resolver endpoints |
| `iam_baseline` | Permission boundary, break-glass role, password policy, Access Analyzer |
| `mfa_enforcement` | SCP: deny console without MFA |
| `sso` | IAM Identity Center: ReadOnly / Developer / SecurityOps sets |
| `security_alerts` | GuardDuty org-wide + SNS critical alert topic |
| `security_hub` | Security Hub aggregator + 3 standards |
| `inspector` | Inspector v2 (EC2/ECR/Lambda) |
| `config_rules` | 25 managed Config rules mapped to FORGE control IDs |
| `tls_enforcement` | SCP: TLS ≥ 1.2 + ACM wildcard cert |
| `remediate_s3` | Lambda: auto-block S3 public access |
| `remediate_mfa` | Lambda: disable console access for users without MFA |
| `remediate_ebs` | Lambda: enable EBS encryption by default |
| `remediate_sg` | Lambda: remove wildcard ingress on sensitive ports |
| `remediate_rds` | Lambda: SNS alert for unencrypted RDS (see runbook) |

## Prerequisites

1. An AWS management account with Organizations enabled.
2. Terraform >= 1.5.0 installed locally.
3. AWS credentials with `AdministratorAccess` on the management account.
4. A registered domain name for ACM certificate validation.

## Quick Start

```bash
# 1. Clone and navigate
git clone https://github.com/your-org/forge.git
cd forge/examples/baseline-regulated

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 3. Initialize
terraform init
```

> **Existing AWS Organization?** Import it before the first apply to avoid `AlreadyInOrganizationException`:
> ```bash
> ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
> terraform import module.organization.aws_organizations_organization.this "$ORG_ID"
> ```

```bash
# 4. Plan and apply
terraform plan -out=plan.out
terraform apply plan.out
```

## Estimated Time to Compliance

| Phase | Duration | What Happens |
|-------|----------|--------------|
| Bootstrap | ~15 min | Organization, SCPs, KMS keys applied |
| Logging | ~5 min | CloudTrail + S3 Object Lock active |
| Network | ~10 min | VPC, subnets, NAT GWs provisioned |
| Security | ~10 min | GuardDuty, Security Hub, Inspector enabled |
| Remediation | ~5 min | Lambda functions deployed and triggered |
| **Total** | **~45 min** | Full SOC 2 control coverage active |

## Protected Resources and Break-Glass Operations

FORGE baseline includes protected resources that should not be force-deleted by default.
Use the break-glass runbook before emergency teardown actions:
[docs/runbooks/break-glass-procedure.md](../../docs/runbooks/break-glass-procedure.md).

Common protected resources in this profile:

- `module.organization.aws_organizations_organization.this`
- `module.kms.*` (key policy deny on `kms:ScheduleKeyDeletion` for non-break-glass)
- Immutable logging resources in `module.logging` (Object Lock / compliance retention)

Recommended teardown pattern:

```bash
cd examples/baseline-regulated

# 1) Detach protected resources from Terraform state
terraform state rm module.organization.aws_organizations_organization.this
terraform state rm $(terraform state list | grep 'module.kms')

# Optional: if immutable logging resources block destroy
terraform state list | grep 'module.logging' | grep -E 's3_bucket|object_lock|lifecycle'
# terraform state rm <each-matching-address>

# 2) Destroy remaining resources
terraform plan -destroy -out=destroy.out
terraform apply destroy.out
```

Manual post-destroy actions (break-glass role required for key deletion):

```bash
# Example: schedule KMS key deletion after policy update per runbook
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 7
```

## Compliance Coverage

- **SOC 2 Type II**: CC1-CC9, A1, C1, PI1 (all categories covered)
- **NIST SP 800-53 Rev 5**: AC, AU, CA, CM, IA, IR, RA, SC, SI families
- **HIPAA Security Rule**: 164.308, 164.310, 164.312 safeguards
- **FFIEC CAT**: All 5 domains (D1–D5) at Baseline maturity
