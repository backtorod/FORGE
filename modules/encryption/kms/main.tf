################################################################################
# FORGE — Encryption: KMS Key Hierarchy
# Purpose-built key per service domain; all keys have rotation enabled
# Regulatory: NIST SC-12, SC-28 | SOC2 CC6.7 | HIPAA 164.312(a)(2)(iv)
################################################################################

data "aws_caller_identity" "current" {}

locals {
  key_definitions = {
    cloudtrail    = { description = "FORGE: CloudTrail log encryption",     service = "cloudtrail.amazonaws.com" }
    s3_logs       = { description = "FORGE: S3 log archive encryption",     service = "s3.amazonaws.com" }
    guardduty     = { description = "FORGE: GuardDuty findings encryption", service = "guardduty.amazonaws.com" }
    rds           = { description = "FORGE: RDS database encryption",       service = "rds.amazonaws.com" }
    secrets       = { description = "FORGE: Secrets Manager encryption",    service = "secretsmanager.amazonaws.com" }
    ebs           = { description = "FORGE: EBS volume encryption",         service = "ec2.amazonaws.com" }
    sns           = { description = "FORGE: SNS topic encryption",          service = "sns.amazonaws.com" }
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
          Service = each.value.service
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
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
    NIST_Control     = "SC-12, SC-28"
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
