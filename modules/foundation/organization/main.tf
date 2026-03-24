################################################################################
# FORGE — Foundation: AWS Organization
# Creates the AWS Organization, Organizational Units, and wires the SCP library
################################################################################

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "inspector2.amazonaws.com",
    "sso.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
  ]

  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]
}

# -----------------------------------------------------------------------------
# Organizational Units
# -----------------------------------------------------------------------------

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Workloads-Production"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads_nonprod" {
  name      = "Workloads-NonProduction"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# -----------------------------------------------------------------------------
# Accounts
# -----------------------------------------------------------------------------

resource "aws_organizations_account" "log_archive" {
  name      = "${var.org_prefix}-log-archive"
  email     = var.log_archive_account_email
  parent_id = aws_organizations_organizational_unit.security.id

  lifecycle {
    ignore_changes = [email, name]  # Prevent drift if account pre-exists
  }

  tags = merge(var.tags, {
    AccountPurpose = "log-archive"
    FORGE_Tier     = "security"
  })
}

resource "aws_organizations_account" "audit" {
  name      = "${var.org_prefix}-audit"
  email     = var.audit_account_email
  parent_id = aws_organizations_organizational_unit.security.id

  lifecycle {
    ignore_changes = [email, name]
  }

  tags = merge(var.tags, {
    AccountPurpose = "audit"
    FORGE_Tier     = "security"
  })
}

resource "aws_organizations_account" "network" {
  name      = "${var.org_prefix}-network"
  email     = var.network_account_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  lifecycle {
    ignore_changes = [email, name]
  }

  tags = merge(var.tags, {
    AccountPurpose = "network"
    FORGE_Tier     = "infrastructure"
  })
}

resource "aws_organizations_account" "shared_services" {
  name      = "${var.org_prefix}-shared-services"
  email     = var.shared_services_account_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  lifecycle {
    ignore_changes = [email, name]
  }

  tags = merge(var.tags, {
    AccountPurpose = "shared-services"
    FORGE_Tier     = "infrastructure"
  })
}
