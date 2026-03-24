output "tls_scp_id" { value = aws_organizations_policy.deny_non_tls.id }
output "acm_certificate_arn" { value = aws_acm_certificate.internal.arn }
output "acm_certificate_validation_options" {
  value = aws_acm_certificate.internal.domain_validation_options
}
