################################################################################
# FORGE — Security: Security Hub (Aggregated)
# All member account findings aggregated to Audit account Security Hub
# Regulatory: NIST SI-4, CA-7 | SOC2 CC4.1, CC7.2
################################################################################

# Delegate Security Hub admin to Audit account
resource "aws_securityhub_organization_admin_account" "this" {
  admin_account_id = var.audit_account_id
}

# Enable Security Hub in Audit account with all standards
resource "aws_securityhub_account" "audit" {}

resource "aws_securityhub_organization_configuration" "this" {
  auto_enable           = true
  auto_enable_standards = "NONE"  # Managed explicitly below

  depends_on = [aws_securityhub_account.audit]
}

# Enable compliance standards
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.audit]
}

resource "aws_securityhub_standards_subscription" "cis_v3" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/3.0.0"
  depends_on    = [aws_securityhub_account.audit]
}

resource "aws_securityhub_standards_subscription" "nist_800_53" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.audit]
}

data "aws_region" "current" {}

# Aggregation region (findings from all regions sent here)
resource "aws_securityhub_finding_aggregator" "this" {
  linking_mode = "ALL_REGIONS"
  depends_on   = [aws_securityhub_account.audit]
}

# SNS topic for CRITICAL findings
resource "aws_securityhub_action_target" "critical_findings" {
  name        = "FORGE-CriticalFindingAlert"
  identifier  = "ForgeCriticalAlert"
  description = "Send CRITICAL Security Hub findings to SNS"
}
