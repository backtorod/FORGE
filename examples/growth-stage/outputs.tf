################################################################################
# FORGE — Growth-Stage Example: Outputs
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

output "primary_alb_security_group_id" {
  description = "Security group ID for the primary region ALB tier."
  value       = module.vpc_primary.alb_security_group_id
}

output "primary_app_security_group_id" {
  description = "Security group ID for the primary region application tier."
  value       = module.vpc_primary.app_security_group_id
}

output "primary_nat_gateway_public_ips" {
  description = "Public IP addresses of the primary region NAT Gateways (for allow-listing)."
  value       = module.vpc_primary.nat_gateway_public_ips
}

# ---------------------------------------------------------------------------
# VPC — Secondary Region
# ---------------------------------------------------------------------------

output "secondary_vpc_id" {
  description = "Secondary region production VPC ID."
  value       = module.vpc_secondary.vpc_id
}

output "secondary_vpc_cidr" {
  description = "Secondary region production VPC CIDR block."
  value       = module.vpc_secondary.vpc_cidr
}

output "secondary_public_subnet_ids" {
  description = "Secondary region public (ALB-tier) subnet IDs."
  value       = module.vpc_secondary.public_subnet_ids
}

output "secondary_private_app_subnet_ids" {
  description = "Secondary region application-tier private subnet IDs."
  value       = module.vpc_secondary.private_app_subnet_ids
}

output "secondary_private_data_subnet_ids" {
  description = "Secondary region data-tier private subnet IDs."
  value       = module.vpc_secondary.private_data_subnet_ids
}

output "secondary_nat_gateway_public_ips" {
  description = "Public IP addresses of the secondary region NAT Gateways."
  value       = module.vpc_secondary.nat_gateway_public_ips
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

output "permission_set_read_only_arn" {
  description = "ARN of the Read-Only IAM Identity Center permission set."
  value       = module.sso.permission_set_read_only_arn
}

output "permission_set_developer_arn" {
  description = "ARN of the Developer IAM Identity Center permission set."
  value       = module.sso.permission_set_developer_arn
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

output "ou_workloads_prod_id" {
  description = "OU ID for production workloads."
  value       = module.organization.ou_workloads_prod_id
}

output "ou_workloads_nonprod_id" {
  description = "OU ID for non-production workloads."
  value       = module.organization.ou_workloads_nonprod_id
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
  description = "SNS topic ARN for critical security findings and break-glass alerts."
  value       = module.guardduty.alerts_topic_arn
}

output "security_hub_finding_aggregator_arn" {
  description = "Security Hub finding aggregator ARN (cross-region roll-up)."
  value       = module.security_hub.finding_aggregator_arn
}

output "config_aggregator_arn" {
  description = "ARN of the organization-wide AWS Config aggregator."
  value       = aws_config_configuration_aggregator.org.arn
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

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

output "log_archive_bucket_name" {
  description = "Name of the immutable CloudTrail / VPC Flow Log S3 bucket."
  value       = module.logging.log_archive_bucket_name
}

output "log_archive_bucket_arn" {
  description = "ARN of the immutable CloudTrail / VPC Flow Log S3 bucket."
  value       = module.logging.log_archive_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization-wide CloudTrail trail."
  value       = module.logging.cloudtrail_arn
}

# ---------------------------------------------------------------------------
# WAFv2
# ---------------------------------------------------------------------------

output "waf_web_acl_arn" {
  description = "ARN of the regional WAFv2 WebACL (attach to ALBs or API Gateways)."
  value       = aws_wafv2_web_acl.regional.arn
}

output "waf_web_acl_id" {
  description = "ID of the regional WAFv2 WebACL."
  value       = aws_wafv2_web_acl.regional.id
}
