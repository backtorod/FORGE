output "organization_id" {
  description = "AWS Organizations ID."
  value       = module.organization.organization_id
}

output "vpc_id" {
  description = "Production VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Production VPC CIDR."
  value       = module.vpc.vpc_cidr
}

output "private_app_subnet_ids" {
  description = "Application-tier private subnet IDs."
  value       = module.vpc.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "Data-tier private subnet IDs."
  value       = module.vpc.private_data_subnet_ids
}

output "break_glass_role_arn" {
  description = "ARN of the FORGE break-glass emergency access role."
  value       = module.iam_baseline.break_glass_role_arn
}

output "log_bucket_name" {
  description = "Name of the immutable CloudTrail / VPC Flow Log bucket."
  value       = module.logging.log_archive_bucket_name
}

output "security_sns_topic_arn" {
  description = "SNS topic ARN for critical security findings."
  value       = module.security_alerts.alerts_topic_arn
}

output "kms_key_arns" {
  description = "Map of KMS key aliases to ARNs."
  value = {
    cloudtrail      = module.kms.cloudtrail_key_arn
    s3_logs         = module.kms.s3_logs_key_arn
    guardduty       = module.kms.key_arns["guardduty"]
    rds             = module.kms.rds_key_arn
    secrets         = module.kms.secrets_key_arn
    ebs             = module.kms.ebs_key_arn
    sns             = module.kms.key_arns["sns"]
    identity_center = module.kms.identity_center_key_arn
  }
}
