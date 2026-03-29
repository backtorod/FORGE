################################################################################
# FORGE — Foundation: Service Control Policies (SCP) Library
# Deploys and attaches the FORGE SCP library to the organization root and OUs
################################################################################

locals {
  # Map of policy name → JSON file path
  policies = {
    deny_cloudtrail_modification = "${path.module}/policies/deny-cloudtrail-modification.json"
    deny_root_account            = "${path.module}/policies/deny-root-account.json"
    deny_regions                 = "${path.module}/policies/deny-regions.json"
    enforce_mfa                  = "${path.module}/policies/enforce-mfa.json"
    deny_secrets_manager_delete  = "${path.module}/policies/deny-secrets-manager-delete.json"
    # Combined workload guardrails (S3 encryption, S3 TLS, EBS encryption,
    # public RDS, public internet) — merged into one policy to stay within
    # the AWS limit of 5 SCPs per target.
    workload_guardrails          = "${path.module}/policies/workload-guardrails.json"
  }
}

resource "aws_organizations_policy" "this" {
  for_each = local.policies

  name        = "FORGE-${replace(each.key, "_", "-")}"
  description = "FORGE immutable guardrail: ${each.key}"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file(each.value)

  tags = merge(var.tags, {
    FORGE_Component = "scp"
    FORGE_Policy    = each.key
  })
}

# -----------------------------------------------------------------------------
# Attach policies to Organization Root (applies to ALL accounts)
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "root_deny_cloudtrail" {
  policy_id = aws_organizations_policy.this["deny_cloudtrail_modification"].id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "root_deny_root_account" {
  policy_id = aws_organizations_policy.this["deny_root_account"].id
  target_id = var.organization_root_id
}

resource "aws_organizations_policy_attachment" "root_deny_regions" {
  policy_id = aws_organizations_policy.this["deny_regions"].id
  target_id = var.organization_root_id
}

# -----------------------------------------------------------------------------
# Attach policies to Workload OUs (production + non-production)
# -----------------------------------------------------------------------------

# Use an index-keyed map so for_each keys are statically known at plan time,
# even though the OU IDs themselves are computed from the organization module.
locals {
  workload_ou_map = { for idx, id in var.workload_ou_ids : tostring(idx) => id }
}

# -----------------------------------------------------------------------------
# Attach combined workload guardrail policy to Workload OUs
# All workload-scoped controls are merged into a single SCP to stay within
# the AWS hard limit of 5 SCPs per target (OU or account).
# -----------------------------------------------------------------------------

resource "aws_organizations_policy_attachment" "workload_guardrails" {
  for_each = local.workload_ou_map

  policy_id = aws_organizations_policy.this["workload_guardrails"].id
  target_id = each.value
}
