################################################################################
# FORGE — Encryption: TLS Enforcement
# SCP denying non-TLS API calls; ACM certificate management
# Regulatory: NIST SC-8, SC-23 | SOC2 CC6.7 | HIPAA 164.312(e)(1)
################################################################################

# SCP: deny any API call not over TLS (org-wide)
resource "aws_organizations_policy" "deny_non_tls" {
  name        = "FORGE-DenyNonTLS"
  description = "FORGE: Deny all S3 requests not using TLS — NIST SC-8"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-non-tls.json")

  tags = merge(var.tags, {
    FORGE_Control = "ENC-TLS-001"
    NIST_Control  = "SC-8 SC-23"
    SOC2_Control  = "CC6.7"
  })
}

resource "aws_organizations_policy_attachment" "deny_non_tls" {
  policy_id = aws_organizations_policy.deny_non_tls.id
  target_id = var.organization_root_id
}

# ACM wildcard certificate for internal domains (auto-renewed by ACM)
resource "aws_acm_certificate" "internal" {
  domain_name               = "*.${var.internal_domain}"
  subject_alternative_names = [var.internal_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    FORGE_Control = "ENC-TLS-002"
    NIST_Control  = "SC-17"
  })
}
