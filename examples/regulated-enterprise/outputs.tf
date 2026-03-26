################################################################################
# FORGE — Regulated-Enterprise Example: Outputs
################################################################################

# ---------------------------------------------------------------------------
# VPC — Primary Region
# ---------------------------------------------------------------------------

output "primary_vpc_id" {
  description = "Primary production VPC ID."
  value       = module.vpc_primary.vpc_id
}

output "primary_vpc_cidr" {
  description = "Primary production VPC CIDR block."
  value       = module.vpc_primary.vpc_cidr
}

output "primary_public_subnet_ids" {
  description = "Primary region public (ALB-tier) subnet IDs."
  value       = module.vpc_primary.public_subnet_ids
}

output "primary_private_app_subnet_ids" {
  description = "Primary region application-tier private subnet IDs."
  value       = module.vpc_primary.private_app_subnet_ids
}

output "primary_private_data_subnet_ids" {
  description = "Primary region data-tier private subnet IDs."
  value       = module.vpc_primary.private_data_subnet_ids
}

output "primary_nat_gateway_public_ips" {
  description = "Public IPs of the primary region NAT Gateways (for egress allow-listing)."
  value       = module.vpc_primary.nat_gateway_public_ips
}

# ---------------------------------------------------------------------------
# VPC — Secondary Region
# ---------------------------------------------------------------------------

output "secondary_vpc_id" {
  description = "Secondary region production VPC ID."
  value       = module.vpc_secondary.vpc_id
}

output "secondary_private_app_subnet_ids" {
  description = "Secondary region application-tier private subnet IDs."
  value       = module.vpc_secondary.private_app_subnet_ids
}

output "secondary_private_data_subnet_ids" {
  description = "Secondary region data-tier private subnet IDs."
  value       = module.vpc_secondary.private_data_subnet_ids
}

# ---------------------------------------------------------------------------
# Network Firewall
# ---------------------------------------------------------------------------

output "network_firewall_arn" {
  description = "ARN of the AWS Network Firewall protecting the primary VPC."
  value       = aws_networkfirewall_firewall.main.arn
}

output "network_firewall_id" {
  description = "ID of the AWS Network Firewall."
  value       = aws_networkfirewall_firewall.main.id
}

output "network_firewall_policy_arn" {
  description = "ARN of the Network Firewall policy."
  value       = aws_networkfirewall_firewall_policy.main.arn
}

output "firewall_subnet_ids" {
  description = "Subnet IDs reserved for Network Firewall endpoints."
  value       = [for s in aws_subnet.firewall : s.id]
}

output "firewall_flow_log_group_name" {
  description = "CloudWatch log group name for Network Firewall flow logs."
  value       = aws_cloudwatch_log_group.firewall_flow.name
}

output "firewall_alert_log_group_name" {
  description = "CloudWatch log group name for Network Firewall alert logs."
  value       = aws_cloudwatch_log_group.firewall_alert.name
}

# ---------------------------------------------------------------------------
# IAM / Identity
# ---------------------------------------------------------------------------

output "break_glass_role_arn" {
  description = "ARN of the FORGE break-glass emergency access role."
  value       = module.iam_baseline.break_glass_role_arn
}

output "permission_boundary_arn" {
  description = "ARN of the FORGE IAM permission boundary policy."
  value       = module.iam_baseline.permission_boundary_arn
}

output "access_analyzer_arn" {
  description = "ARN of the organization-wide IAM Access Analyzer."
  value       = module.iam_baseline.access_analyzer_arn
}

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center (SSO) instance."
  value       = module.sso.sso_instance_arn
}

output "permission_set_security_ops_arn" {
  description = "ARN of the SecurityOps IAM Identity Center permission set."
  value       = module.sso.permission_set_security_ops_arn
}

# ---------------------------------------------------------------------------
# Organization
# ---------------------------------------------------------------------------

output "organization_id" {
  description = "AWS Organizations ID."
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "AWS Organizations ARN."
  value       = module.organization.organization_arn
}

output "log_archive_account_id" {
  description = "Account ID of the Log Archive member account."
  value       = module.organization.log_archive_account_id
}

output "audit_account_id" {
  description = "Account ID of the Audit member account."
  value       = module.organization.audit_account_id
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------

output "guardduty_detector_id" {
  description = "GuardDuty delegated-admin detector ID."
  value       = module.guardduty.detector_id
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for critical security findings."
  value       = module.guardduty.alerts_topic_arn
}

output "security_hub_finding_aggregator_arn" {
  description = "Security Hub finding aggregator ARN."
  value       = module.security_hub.finding_aggregator_arn
}

output "config_aggregator_arn" {
  description = "ARN of the organization-wide AWS Config aggregator."
  value       = aws_config_configuration_aggregator.org.arn
}

output "nist_conformance_pack_arn" {
  description = "ARN of the NIST 800-53 Rev 5 Config conformance pack."
  value       = aws_config_conformance_pack.nist_800_53.arn
}

# ---------------------------------------------------------------------------
# Audit Manager
# ---------------------------------------------------------------------------

output "audit_manager_framework_arn" {
  description = "ARN of the FORGE Audit Manager custom assessment framework."
  value       = var.enable_audit_manager ? aws_auditmanager_framework.forge[0].arn : null
}

output "audit_manager_assessment_arn" {
  description = "ARN of the FORGE Audit Manager assessment."
  value       = var.enable_audit_manager ? aws_auditmanager_assessment.forge[0].arn : null
}

# ---------------------------------------------------------------------------
# Backup Vaults
# ---------------------------------------------------------------------------

output "primary_backup_vault_arn" {
  description = "ARN of the primary-region AWS Backup vault."
  value       = aws_backup_vault.primary.arn
}

output "primary_backup_vault_name" {
  description = "Name of the primary-region AWS Backup vault."
  value       = aws_backup_vault.primary.name
}

output "secondary_backup_vault_arn" {
  description = "ARN of the secondary-region AWS Backup vault (cross-account copy target)."
  value       = aws_backup_vault.secondary.arn
}

output "backup_plan_id" {
  description = "ID of the centralized AWS Backup plan."
  value       = aws_backup_plan.main.id
}

output "backup_plan_arn" {
  description = "ARN of the centralized AWS Backup plan."
  value       = aws_backup_plan.main.arn
}

# ---------------------------------------------------------------------------
# SIEM — EventBridge
# ---------------------------------------------------------------------------

output "siem_event_bus_arn" {
  description = "ARN of the cross-account EventBridge bus used for SIEM ingestion."
  value       = var.enable_siem_event_bus ? aws_cloudwatch_event_bus.siem[0].arn : null
}

output "siem_event_bus_name" {
  description = "Name of the SIEM EventBridge custom event bus."
  value       = var.enable_siem_event_bus ? aws_cloudwatch_event_bus.siem[0].name : null
}

# ---------------------------------------------------------------------------
# Encryption
# ---------------------------------------------------------------------------

output "kms_key_arns" {
  description = "Map of KMS key domain to ARN."
  value = {
    cloudtrail = module.kms.cloudtrail_key_arn
    s3_logs    = module.kms.s3_logs_key_arn
    rds        = module.kms.rds_key_arn
    secrets    = module.kms.secrets_key_arn
    ebs        = module.kms.ebs_key_arn
  }
}

output "waf_web_acl_arn" {
  description = "ARN of the enterprise regional WAFv2 WebACL."
  value       = aws_wafv2_web_acl.regional.arn
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

output "log_archive_bucket_name" {
  description = "Name of the immutable CloudTrail / VPC Flow Log S3 bucket."
  value       = module.logging.log_archive_bucket_name
}

output "log_archive_bucket_arn" {
  description = "ARN of the immutable log archive S3 bucket."
  value       = module.logging.log_archive_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization-wide CloudTrail trail."
  value       = module.logging.cloudtrail_arn
}
