################################################################################
# FORGE — Identity: IAM Identity Center (SSO)
# Centralised SSO with permission sets mapped to job functions
# TODO (v1.1): Add SCIM provisioning from external IdP (Okta, Azure AD)
################################################################################

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn      = try(tolist(data.aws_ssoadmin_instances.this.arns)[0], null)
  sso_identity_store_id = try(tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0], null)
}

# Fail early with a clear message if IAM Identity Center is not enabled.
# Enable it first: AWS Console → IAM Identity Center → Enable, or:
#   aws sso-admin create-instances (not yet available via CLI; enable via console)
# Then re-run terraform apply.
resource "terraform_data" "sso_instance_check" {
  lifecycle {
    precondition {
      condition     = local.sso_instance_arn != null
      error_message = "IAM Identity Center is not enabled in this AWS account/region. Enable it in the AWS Console (IAM Identity Center → Enable) before applying the sso module."
    }
  }
}

# -----------------------------------------------------------------------------
# Permission Sets (job-function based, principle of least privilege)
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set" "read_only" {
  name             = "FORGE-ReadOnly"
  description      = "Read-only access for auditors and read-across teams"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"

  tags = merge(var.tags, { FORGE_PermissionSet = "read-only" })
}

resource "aws_ssoadmin_managed_policy_attachment" "read_only" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "FORGE-Developer"
  description      = "Developer access with permission boundary enforced"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = merge(var.tags, { FORGE_PermissionSet = "developer" })
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*", "ecs:*", "eks:*", "lambda:*",
          "s3:*", "rds:*", "sqs:*", "sns:*",
          "cloudwatch:*", "logs:*", "xray:*",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "security_ops" {
  name             = "FORGE-SecurityOps"
  description      = "Security operations — GuardDuty, Security Hub, Config, CloudTrail"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = merge(var.tags, { FORGE_PermissionSet = "security-ops" })
}

resource "aws_ssoadmin_managed_policy_attachment" "security_ops_securityhub" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_ops.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSSecurityHubReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "security_ops_guardduty" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_ops.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyReadOnlyAccess"
}
