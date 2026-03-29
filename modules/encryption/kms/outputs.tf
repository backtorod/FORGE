output "key_arns" {
  description = "Map of key domain name to KMS key ARN"
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "key_ids" {
  description = "Map of key domain name to KMS key ID"
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
}

output "alias_arns" {
  description = "Map of key domain name to KMS alias ARN"
  value       = { for k, v in aws_kms_alias.this : k => v.arn }
}

# Convenience outputs for common consumers
output "cloudtrail_key_arn" { value = aws_kms_key.this["cloudtrail"].arn }
output "s3_logs_key_arn"    { value = aws_kms_key.this["s3_logs"].arn }
output "rds_key_arn"         { value = aws_kms_key.this["rds"].arn }
output "secrets_key_arn"     { value = aws_kms_key.this["secrets"].arn }
output "ebs_key_arn"         { value = aws_kms_key.this["ebs"].arn }
output "sns_key_id"               { value = aws_kms_key.this["sns"].key_id }
output "identity_center_key_arn" { value = aws_kms_key.this["identity_center"].arn }
