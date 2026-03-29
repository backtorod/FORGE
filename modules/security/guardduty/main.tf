################################################################################
# FORGE — Security: GuardDuty (Organization-Wide)
# Delegated to Audit account; all member accounts auto-enrolled
# Regulatory: NIST IR-4, SI-4 | SOC2 CC7.2, CC7.3
################################################################################

# Delegate GuardDuty administration to the Audit account
resource "aws_guardduty_organization_admin_account" "this" {
  admin_account_id = var.audit_account_id
}

# Org-wide configuration (runs in context of delegated admin / Audit account)
resource "aws_guardduty_detector" "audit" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = merge(var.tags, {
    FORGE_Control = "SEC-001"
    NIST_Control  = "IR-4, SI-4"
    SOC2_Control  = "CC7.2, CC7.3"
  })
}

# Detector features — replaces deprecated datasources block
resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "malware_protection" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

resource "aws_guardduty_organization_configuration" "this" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.audit.id
}

# Org-wide feature enablement — replaces deprecated datasources block
resource "aws_guardduty_organization_configuration_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "S3_DATA_EVENTS"
  auto_enable = "ALL"
}

resource "aws_guardduty_organization_configuration_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "EKS_AUDIT_LOGS"
  auto_enable = "ALL"
}

resource "aws_guardduty_organization_configuration_feature" "ebs_malware_protection" {
  detector_id = aws_guardduty_detector.audit.id
  name        = "EBS_MALWARE_PROTECTION"
  auto_enable = "ALL"
}

# SNS notification for High/Critical findings
resource "aws_sns_topic" "guardduty_alerts" {
  name              = "forge-guardduty-alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, { FORGE_Control = "SEC-002" })
}

resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "forge-guardduty-high-severity"
  description = "FORGE: Route HIGH and CRITICAL GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = merge(var.tags, { FORGE_Control = "SEC-003" })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "guardduty-to-sns"
  arn       = aws_sns_topic.guardduty_alerts.arn
}
