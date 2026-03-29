################################################################################
# FORGE — Encryption: TLS Enforcement
# ACM certificate management — S3 TLS enforcement is covered by the SCP in
# modules/foundation/scp/policies/workload-guardrails.json (DenyS3NonTLSRequests)
# Regulatory: NIST SC-8, SC-23 | SOC2 CC6.7 | HIPAA 164.312(e)(1)
################################################################################

# ACM wildcard certificate for the registered domain — auto-validated via Route 53
data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "internal" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    FORGE_Control = "ENC-TLS-002"
    NIST_Control  = "SC-17"
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.internal.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "internal" {
  certificate_arn         = aws_acm_certificate.internal.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
