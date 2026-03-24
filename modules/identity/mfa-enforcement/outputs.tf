output "mfa_scp_id" {
  description = "ID of the MFA enforcement SCP"
  value       = aws_organizations_policy.enforce_mfa.id
}

output "mfa_scp_arn" {
  description = "ARN of the MFA enforcement SCP"
  value       = aws_organizations_policy.enforce_mfa.arn
}
