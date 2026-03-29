################################################################################
# FORGE — Identity: IAM Baseline
# Permission boundaries, break-glass role, instance profiles
# Regulatory: NIST AC-2, AC-3, IA-2 | SOC2 CC6.1, CC6.3
################################################################################

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Permission Boundary — applied to all developer-created roles
# Limits the maximum permissions any role can have
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "permission_boundary" {
  name        = "FORGE-PermissionBoundary"
  description = "FORGE permission boundary - maximum permissions for developer-created roles"
  path        = "/forge/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowComputeAndApp"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*",
          "eks:*",
          "lambda:*",
          "s3:*",
          "rds:*",
          "sqs:*",
          "sns:*",
          "secretsmanager:GetSecretValue",
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "logs:*",
          "xray:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyPrivilegeEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:PutUserPolicy",
          "iam:AttachUserPolicy",
          "iam:CreateAccessKey",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRolePermissionsBoundary",
          "iam:UpdateAssumeRolePolicy",
          "organizations:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyLeavingOrg"
        Effect = "Deny"
        Action = [
          "organizations:LeaveOrganization"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    FORGE_Control = "IAM-001"
    NIST_Control  = "AC-3 AC-6"
    SOC2_Control  = "CC6.1"
  })
}

# -----------------------------------------------------------------------------
# Break-Glass Role (emergency access — all use is logged and alerted)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "break_glass" {
  name                 = "forge-break-glass-admin"
  path                 = "/forge/"
  max_session_duration = 3600  # 1 hour maximum

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.break_glass_trusted_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "900"  # MFA used within 15 minutes
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    FORGE_Control = "IAM-002"
    NIST_Control  = "AC-2-5"
    Description   = "Emergency break-glass access - all use triggers CloudWatch alarm"
  })
}

resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  role       = aws_iam_role.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Metric filter on CloudTrail log group — fires when break-glass role is assumed
resource "aws_cloudwatch_log_metric_filter" "break_glass_used" {
  name           = "forge-break-glass-assume-role"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventName = \"AssumeRole\") && ($.requestParameters.roleArn = \"*${aws_iam_role.break_glass.name}*\") }"

  metric_transformation {
    name      = "BreakGlassRoleUsed"
    namespace = "FORGE/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "break_glass_used" {
  alarm_name          = "forge-break-glass-role-used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "BreakGlassRoleUsed"
  namespace           = "FORGE/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "FORGE: break-glass role was assumed. Immediate review required."
  alarm_actions       = var.security_sns_topic_arns
  ok_actions          = []

  tags = merge(var.tags, { FORGE_Control = "IAM-003" })
}

# -----------------------------------------------------------------------------
# Password Policy
# -----------------------------------------------------------------------------

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 16
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  require_uppercase_characters   = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# -----------------------------------------------------------------------------
# IAM Access Analyzer (org-wide)
# -----------------------------------------------------------------------------

resource "aws_accessanalyzer_analyzer" "org" {
  analyzer_name = "forge-org-analyzer"
  type          = "ORGANIZATION"

  tags = merge(var.tags, {
    FORGE_Control = "IAM-004"
    NIST_Control  = "AC-6-9 RA-5"
  })
}
