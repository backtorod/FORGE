output "permission_boundary_arn" {
  description = "ARN of the FORGE permission boundary policy"
  value       = aws_iam_policy.permission_boundary.arn
}

output "break_glass_role_arn" {
  description = "ARN of the break-glass emergency access role"
  value       = aws_iam_role.break_glass.arn
}

output "access_analyzer_arn" {
  description = "ARN of the organization-wide IAM Access Analyzer"
  value       = aws_accessanalyzer_analyzer.org.arn
}
