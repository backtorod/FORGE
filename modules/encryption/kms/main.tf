################################################################################
# FORGE — Encryption: KMS Key Hierarchy
# Purpose-built key per service domain; all keys have rotation enabled
# Regulatory: NIST SC-12, SC-28 | SOC2 CC6.7 | HIPAA 164.312(a)(2)(iv)
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  default_service_actions = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]

  key_definitions = {
    # CloudTrail key also used for CloudWatch Logs log group and Config S3 delivery
    cloudtrail      = { description = "FORGE: CloudTrail log encryption",          services = ["cloudtrail.amazonaws.com", "logs.${data.aws_region.current.region}.amazonaws.com", "config.amazonaws.com"], actions = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"] }
    s3_logs         = { description = "FORGE: S3 log archive encryption",          services = ["s3.amazonaws.com", "config.amazonaws.com"],    actions = local.default_service_actions }
    guardduty       = { description = "FORGE: GuardDuty findings encryption",      services = ["guardduty.amazonaws.com"],             actions = local.default_service_actions }
    rds             = { description = "FORGE: RDS database encryption",            services = ["rds.amazonaws.com"],                   actions = local.default_service_actions }
    secrets         = { description = "FORGE: Secrets Manager encryption",         services = ["secretsmanager.amazonaws.com"],         actions = local.default_service_actions }
    ebs             = { description = "FORGE: EBS volume encryption",              services = ["ec2.amazonaws.com"],                   actions = local.default_service_actions }
    sns             = { description = "FORGE: SNS topic encryption",               services = ["sns.amazonaws.com"],                   actions = local.default_service_actions }
    # IAM Identity Center requires ReEncrypt* and CreateGrant for key usage during data migrations/rotations
    identity_center = { description = "FORGE: IAM Identity Center encryption",     services = ["sso.amazonaws.com"],                   actions = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey", "kms:ReEncryptFrom", "kms:ReEncryptTo", "kms:CreateGrant"] }
  }
}

resource "aws_kms_key" "this" {
  for_each = local.key_definitions

  description             = each.value.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true  # Annual rotation — NIST SC-12
  multi_region            = var.multi_region_keys

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = each.value.services
        }
        Action   = each.value.actions
        Resource = "*"
      },
      {
        Sid    = "DenyKeyDeletion"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:DeleteImportedKeyMaterial"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/forge-break-glass-*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    FORGE_Control    = "ENC-${upper(each.key)}"
    NIST_Control     = "SC-12 SC-28"
    SOC2_Control     = "CC6.7"
    KeyDomain        = each.key
    RotationEnabled  = "true"
  })
}

resource "aws_kms_alias" "this" {
  for_each = local.key_definitions

  name          = "alias/forge-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
