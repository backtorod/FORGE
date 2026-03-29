################################################################################
# FORGE — Security: AWS Inspector v2
# Automated vulnerability assessment for EC2, ECR, and Lambda
# Enabled in production workload accounts only (cost optimization)
# Regulatory: NIST RA-5, SI-2 | SOC2 CC7.1
################################################################################

resource "aws_inspector2_enabler" "this" {
  account_ids    = var.target_account_ids
  resource_types = ["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"]
}

resource "aws_inspector2_delegated_admin_account" "this" {
  account_id = var.audit_account_id
}

# NOTE: aws_inspector2_organization_configuration must be applied from the
# delegated admin (Audit) account. Configure auto-enable via the Inspector
# console in the Audit account or a separate Terraform workspace.
