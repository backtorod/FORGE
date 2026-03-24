output "sso_instance_arn" { value = local.sso_instance_arn }
output "permission_set_read_only_arn" { value = aws_ssoadmin_permission_set.read_only.arn }
output "permission_set_developer_arn" { value = aws_ssoadmin_permission_set.developer.arn }
output "permission_set_security_ops_arn" { value = aws_ssoadmin_permission_set.security_ops.arn }
