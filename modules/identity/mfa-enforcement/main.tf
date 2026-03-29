################################################################################
# FORGE — Identity: MFA Enforcement
# SCP-based enforcement; cannot be bypassed by account IAM policies
# Regulatory: NIST IA-2, IA-2(1) | SOC2 CC6.1, CC6.3 | HIPAA 164.312(d)
################################################################################

resource "aws_organizations_policy" "enforce_mfa" {
  name        = "FORGE-EnforceMFA"
  description = "FORGE: Deny console access without MFA — NIST IA-2, SOC2 CC6.1"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/enforce-mfa.json")

  tags = merge(var.tags, {
    FORGE_Control = "IAM-010"
    NIST_Control  = "IA-2 IA-2(1) IA-2(2)"
    SOC2_Control  = "CC6.1 CC6.3"
    HIPAA_Control = "164.312(d)"
    FFIEC_Control = "IS.10 IS.11"
  })
}

resource "aws_organizations_policy_attachment" "enforce_mfa_root" {
  policy_id = aws_organizations_policy.enforce_mfa.id
  target_id = var.organization_root_id
}
