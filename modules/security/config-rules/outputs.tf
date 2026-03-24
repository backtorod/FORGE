output "config_recorder_name" { value = aws_config_configuration_recorder.this.name }
output "config_role_arn" { value = aws_iam_role.config.arn }
output "managed_rule_arns" {
  value = { for k, v in aws_config_config_rule.managed : k => v.arn }
}
