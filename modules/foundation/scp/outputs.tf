output "policy_ids" {
  description = "Map of SCP policy name to policy ID"
  value       = { for k, v in aws_organizations_policy.this : k => v.id }
}

output "policy_arns" {
  description = "Map of SCP policy name to policy ARN"
  value       = { for k, v in aws_organizations_policy.this : k => v.arn }
}
