output "acm_certificate_arn" { value = aws_acm_certificate_validation.internal.certificate_arn }
output "acm_certificate_validation_options" {
  value = aws_acm_certificate.internal.domain_validation_options
}
