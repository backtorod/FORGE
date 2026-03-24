################################################################################
# FORGE — Foundation: Service Control Policies (SCP) Library
# Deploys and attaches the FORGE SCP library to the organization root and OUs
################################################################################

locals {
  # Map of policy name → JSON file path
  policies = {
    deny_unencrypted_s3         = "${path.module}/policies/deny-unencrypted-s3.json"
    deny_cloudtrail_modification = "${path.module}/policies/deny-cloudtrail-modification.json"
    deny_root_account           = "${path.module}/policies/deny-root-account.json"
    deny_public_internet_access = "${path.module}/policies/deny-public-internet-access.json"
    enforce_mfa                 = "${path.module}/policies/enforce-mfa.json"
    deny_regions                = "${path.module}/policies/deny-regions.json"
    deny_unencrypted_ebs        = "${path.module}/policies/deny-unencrypted-ebs.json"
    deny_public_rds             = "${path.module}/policies/deny-public-rds.json"
    enforce_s3_tls              = "${path.module}/policies/enforce-s3-tls.json"
    deny_secrets_manager_delete = "${path.module}/policies/deny-secrets-manager-delete.json"
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

resource "aws_organizations_policy_attachment" "workload_deny_unencrypted_s3" {
  for_each = toset(var.workload_ou_ids)

  policy_id = aws_organizations_policy.this["deny_unencrypted_s3"].id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "workload_enforce_s3_tls" {
  for_each = toset(var.workload_ou_ids)

  policy_id = aws_organizations_policy.this["enforce_s3_tls"].id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "workload_deny_unencrypted_ebs" {
  for_each = toset(var.workload_ou_ids)

  policy_id = aws_organizations_policy.this["deny_unencrypted_ebs"].id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "workload_deny_public_rds" {
  for_each = toset(var.workload_ou_ids)

  policy_id = aws_organizations_policy.this["deny_public_rds"].id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "workload_deny_public_internet" {
  for_each = toset(var.workload_ou_ids)

  policy_id = aws_organizations_policy.this["deny_public_internet_access"].id
  target_id = each.value
}
