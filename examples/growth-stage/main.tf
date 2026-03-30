################################################################################
# FORGE — Example: Growth-Stage Company (50–500 employees, SOC 2 + HIPAA)
#
# Extends baseline-regulated with:
#   • Multi-region active-active VPC topology (primary + secondary region)
#   • Separate staging / production OUs with distinct SCPs
#   • Enhanced IAM Identity Center with SCIM attribute mapping
#   • AWS Config Aggregator across all accounts in the Organization
#   • Amazon Macie for S3 sensitive-data discovery
#   • WAFv2 (Common, Known-Bad-Inputs, SQLi rule sets) — OWASP Top 10 coverage
#   • AWS Shield Standard on internet-facing ALBs
#   • SOC 2 + HIPAA dual-standard Security Hub findings
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # fill in real values
#   terraform init
#   terraform plan
#   terraform apply
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.40.0" }
  }
  # Uncomment to store state remotely (recommended for all non-sandbox environments):
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "forge/growth-stage/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

# Secondary region provider for active-active VPC topology.
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  default_tags { tags = local.common_tags }
}

# WAFv2 WebACLs for CloudFront must be in us-east-1 regardless of primary region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags { tags = local.common_tags }
}

locals {
  common_tags = merge(var.tags, {
    FORGE_Version      = "0.2.0"
    FORGE_Example      = "growth-stage"
    Environment        = "production"
    CostCenter         = var.cost_center
    DataClassification = "Restricted"
  })
}

################################################################################
# Foundation — Organization, SCPs, Centralized Logging
################################################################################

module "organization" {
  source = "../../modules/foundation/organization"

  org_prefix                    = var.org_prefix
  log_archive_account_email     = var.log_archive_account_email
  audit_account_email           = var.audit_account_email
  network_account_email         = var.network_account_email
  shared_services_account_email = var.shared_services_account_email
  tags                          = local.common_tags
}

module "scp" {
  source = "../../modules/foundation/scp"

  org_prefix           = var.org_prefix
  organization_root_id = module.organization.organization_root_id
  # Enforce SCPs on both prod and non-prod OUs.
  workload_ou_ids = [
    module.organization.ou_workloads_prod_id,
    module.organization.ou_workloads_nonprod_id,
  ]
  allowed_regions = var.allowed_regions
  tags            = local.common_tags
}

module "kms" {
  source     = "../../modules/encryption/kms"
  org_prefix = var.org_prefix
  tags       = local.common_tags
}

module "logging" {
  source = "../../modules/foundation/logging"

  org_prefix             = var.org_prefix
  log_archive_account_id = module.organization.log_archive_account_id
  organization_id        = module.organization.organization_id
  kms_key_arn            = module.kms.cloudtrail_key_arn
  tags                   = local.common_tags
}

################################################################################
# Network — Multi-Region Active-Active
################################################################################

module "vpc_primary" {
  source = "../../modules/network/vpc-baseline"

  name_prefix            = "${var.org_prefix}-prod-primary"
  vpc_cidr               = var.vpc_cidr
  az_count               = var.az_count
  log_archive_bucket_arn = module.logging.log_archive_bucket_arn
  tags                   = local.common_tags
}

module "vpc_secondary" {
  source    = "../../modules/network/vpc-baseline"
  providers = { aws = aws.secondary }

  name_prefix            = "${var.org_prefix}-prod-secondary"
  vpc_cidr               = var.secondary_vpc_cidr
  az_count               = var.az_count
  log_archive_bucket_arn = module.logging.log_archive_bucket_arn
  tags                   = local.common_tags
}

module "transit_gateway" {
  source = "../../modules/network/transit-gateway"

  name_prefix            = var.org_prefix
  network_vpc_id         = module.vpc_primary.vpc_id
  network_vpc_subnet_ids = module.vpc_primary.private_app_subnet_ids
  tags                   = local.common_tags
}

# Cloud WAN provides the multi-region managed backbone.
# Both primary and secondary VPCs attach to the "workload" segment.
module "cloud_wan" {
  source = "../../modules/network/cloudwan"

  name_prefix             = var.org_prefix
  edge_locations          = var.allowed_regions
  share_with_organization = true
  organization_arn        = module.organization.organization_arn
  alarm_topic_arns        = [module.guardduty.alerts_topic_arn]

  vpc_attachments = [
    {
      name        = "prod-primary-vpc"
      vpc_arn     = "arn:aws:ec2:${var.aws_region}:${var.account_id}:vpc/${module.vpc_primary.vpc_id}"
      subnet_arns = [for id in module.vpc_primary.private_app_subnet_ids : "arn:aws:ec2:${var.aws_region}:${var.account_id}:subnet/${id}"]
      segment     = "workload"
    },
    {
      name        = "prod-secondary-vpc"
      vpc_arn     = "arn:aws:ec2:${var.secondary_region}:${var.account_id}:vpc/${module.vpc_secondary.vpc_id}"
      subnet_arns = [for id in module.vpc_secondary.private_app_subnet_ids : "arn:aws:ec2:${var.secondary_region}:${var.account_id}:subnet/${id}"]
      segment     = "workload"
    },
  ]

  tags = local.common_tags
}

module "dns" {
  source = "../../modules/network/dns"

  name_prefix                = var.org_prefix
  internal_domain            = var.internal_domain
  network_vpc_id             = module.vpc_primary.vpc_id
  resolver_subnet_ids        = module.vpc_primary.private_app_subnet_ids
  resolver_security_group_id = module.vpc_primary.app_security_group_id
  tags                       = local.common_tags
}

################################################################################
# Identity — IAM Baseline, MFA, IAM Identity Center (SSO) with SCIM
################################################################################

module "iam_baseline" {
  source = "../../modules/identity/iam-baseline"

  org_prefix                = var.org_prefix
  break_glass_trusted_arns  = var.break_glass_trusted_arns
  security_sns_topic_arns   = [module.guardduty.alerts_topic_arn]
  cloudtrail_log_group_name = module.logging.cloudtrail_log_group_name
  tags                      = local.common_tags
}

module "mfa_enforcement" {
  source = "../../modules/identity/mfa-enforcement"

  org_prefix           = var.org_prefix
  organization_root_id = module.organization.organization_root_id
  tags                 = local.common_tags
}

module "sso" {
  source = "../../modules/identity/sso"
  org_prefix = var.org_prefix
  tags   = local.common_tags
}

# SCIM attribute mapping enables automated user/group provisioning from
# your external IdP (Okta, Entra ID, JumpCloud, etc.) into IAM Identity Center.
resource "aws_ssoadmin_instance_access_control_attributes" "scim" {
  count        = var.scim_endpoint_url != "" ? 1 : 0
  instance_arn = module.sso.sso_instance_arn

  attribute {
    key = "email"
    value {
      source = ["$${path:email}"]
    }
  }

  attribute {
    key = "department"
    value {
      source = ["$${path:department}"]
    }
  }
}

################################################################################
# Security — GuardDuty, Security Hub (SOC 2 + HIPAA), Inspector, Config
################################################################################

module "guardduty" {
  source = "../../modules/security/guardduty"

  org_prefix       = var.org_prefix
  audit_account_id = module.organization.audit_account_id
  kms_key_id       = module.kms.sns_key_id
  tags             = local.common_tags
}

module "security_hub" {
  source = "../../modules/security/security-hub"

  org_prefix       = var.org_prefix
  audit_account_id = module.organization.audit_account_id
  tags             = local.common_tags
}

module "inspector" {
  source = "../../modules/security/inspector"

  audit_account_id   = module.organization.audit_account_id
  target_account_ids = length(var.workload_account_ids) > 0 ? var.workload_account_ids : [var.account_id]
  tags               = local.common_tags
}

module "config_rules" {
  source = "../../modules/security/config-rules"

  org_prefix     = var.org_prefix
  s3_kms_key_arn = module.kms.s3_logs_key_arn
  tags           = local.common_tags
}

# Config Aggregator — consolidates findings from every account in the Organization
# so that the security team has a single-pane-of-glass view of compliance posture.
resource "aws_iam_role" "config_aggregator" {
  name               = "${var.org_prefix}-config-aggregator-role"
  assume_role_policy = data.aws_iam_policy_document.config_aggregator_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "config_aggregator_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "org" {
  name = "${var.org_prefix}-org-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator.arn
  }

  tags = local.common_tags
}

# Amazon Macie — discovers sensitive data (PII, PCI, PHI) across S3 buckets.
# Satisfies HIPAA §164.312(a)(2)(iv) discovery requirements.
resource "aws_macie2_account" "this" {
  count                        = var.enable_macie ? 1 : 0
  finding_publishing_frequency = var.macie_finding_publishing_frequency
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "s3_full_scan" {
  count      = var.enable_macie ? 1 : 0
  job_type   = "SCHEDULED"
  name       = "${var.org_prefix}-s3-sensitive-data-discovery"
  depends_on = [aws_macie2_account.this]

  schedule_frequency {
    weekly_schedule = "MONDAY"
  }

  s3_job_definition {
    bucket_definitions {
      account_id = var.account_id
      buckets    = [module.logging.log_archive_bucket_name]
    }
  }

  tags = local.common_tags
}

################################################################################
# Encryption — TLS, KMS
################################################################################

module "tls_enforcement" {
  source = "../../modules/encryption/tls-enforcement"

  domain_name = var.domain_name
  tags        = local.common_tags
}

################################################################################
# WAFv2 — OWASP Top 10 managed rule sets on internet-facing ALBs
################################################################################

resource "aws_wafv2_web_acl" "regional" {
  name  = "${var.org_prefix}-regional-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.org_prefix}CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.org_prefix}KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.org_prefix}SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.org_prefix}RegionalWebACL"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_alb_arn != "" ? 1 : 0
  resource_arn = var.waf_alb_arn
  web_acl_arn  = aws_wafv2_web_acl.regional.arn
}

################################################################################
# Remediation Lambdas
################################################################################

module "remediate_s3" {
  source          = "../../remediation/s3/block-public-access"
  org_prefix      = var.org_prefix
  kms_key_arn     = module.kms.s3_logs_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_mfa" {
  source          = "../../remediation/iam/mfa-gap-remediation"
  org_prefix      = var.org_prefix
  kms_key_arn     = module.kms.secrets_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_ebs" {
  source          = "../../remediation/ec2/encrypt-ebs"
  org_prefix      = var.org_prefix
  kms_key_arn     = module.kms.ebs_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_sg" {
  source          = "../../remediation/network/remove-sg-wildcard"
  org_prefix      = var.org_prefix
  kms_key_arn     = module.kms.s3_logs_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_rds" {
  source          = "../../remediation/rds/encrypt-rds"
  org_prefix      = var.org_prefix
  kms_key_arn     = module.kms.rds_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}
