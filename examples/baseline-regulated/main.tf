################################################################################
# FORGE — Example: Fintech Startup (1–50 employees, SOC 2 Type II target)
#
# This example wires together all FORGE modules for a startup environment.
# It assumes a single AWS Organization with accounts already created, or
# delegates account creation to the organization module.
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
    aws  = { source = "hashicorp/aws",  version = ">= 5.40.0" }
    time = { source = "hashicorp/time", version = ">= 0.9.0" }
  }
  # Uncomment to store state remotely (recommended):
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "forge/fintech-startup/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

# Secondary provider aliases for cross-region VPC peering.
# Add one alias per additional region you deploy VPCs into.
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
  default_tags { tags = local.common_tags }
}

locals {
  common_tags = merge(var.tags, {
    FORGE_Version    = "0.1.0"
    FORGE_Example    = "fintech-startup"
    Environment      = "production"
    CostCenter       = var.cost_center
    DataClassification = "Restricted"
  })
}

################################################################################
# Foundation — Organization, SCPs, Centralized Logging
################################################################################

module "organization" {
  source = "../../modules/foundation/organization"

  org_prefix                  = var.org_prefix
  log_archive_account_email   = var.log_archive_account_email
  audit_account_email         = var.audit_account_email
  network_account_email       = var.network_account_email
  shared_services_account_email = var.shared_services_account_email
  tags                        = local.common_tags
}

module "scp" {
  source = "../../modules/foundation/scp"

  organization_root_id = module.organization.organization_root_id
  workload_ou_ids      = [module.organization.ou_workloads_prod_id]
  allowed_regions      = var.allowed_regions
  tags                 = local.common_tags
}

module "kms" {
  source = "../../modules/encryption/kms"
  tags   = local.common_tags
}

module "logging" {
  source = "../../modules/foundation/logging"

  log_archive_account_id = module.organization.log_archive_account_id
  organization_id        = module.organization.organization_id
  kms_key_arn            = module.kms.cloudtrail_key_arn
  alarm_sns_topic_arns   = [module.security_alerts.alerts_topic_arn]
  tags                   = local.common_tags
}

################################################################################
# Network — VPC, Transit Gateway, DNS
################################################################################

module "vpc" {
  source = "../../modules/network/vpc-baseline"

  name_prefix           = "${var.org_prefix}-prod"
  vpc_cidr              = var.vpc_cidr
  az_count              = var.az_count
  log_archive_bucket_arn = module.logging.log_archive_bucket_arn
  tags                  = local.common_tags
}

module "transit_gateway" {
  source = "../../modules/network/transit-gateway"

  name_prefix            = var.org_prefix
  network_vpc_id         = module.vpc.vpc_id
  network_vpc_subnet_ids = module.vpc.private_app_subnet_ids
  tags                   = local.common_tags
}

# Cloud WAN — org-wide managed backbone (default for FORGE).
# Shares the core network to the entire Organization via RAM so that
# all accounts can attach their VPCs without per-account sharing.
module "cloud_wan" {
  source = "../../modules/network/cloudwan"

  name_prefix             = var.org_prefix
  edge_locations          = var.allowed_regions
  share_with_organization = true
  organization_arn        = module.organization.organization_arn
  alarm_topic_arns        = [module.security_alerts.alerts_topic_arn]

  # Attach the primary prod VPC to the workload segment.
  vpc_attachments = [
    {
      name        = "prod-vpc"
      vpc_arn     = "arn:aws:ec2:${var.aws_region}:${var.account_id}:vpc/${module.vpc.vpc_id}"
      subnet_arns = [for id in module.vpc.private_app_subnet_ids : "arn:aws:ec2:${var.aws_region}:${var.account_id}:subnet/${id}"]
      segment     = "workload"
    }
  ]

  tags = local.common_tags
}

# VPC Peering — intra-account cross-region mesh.
# Only active when var.enable_cross_region_peering = true and a secondary
# VPC has been provisioned in a second region (var.secondary_vpc_*).
# This treats the account as a single network entity across regions.
module "vpc_peering" {
  source = "../../modules/network/vpc-peering"
  count  = var.enable_cross_region_peering ? 1 : 0

  providers = {
    aws          = aws
    aws.accepter = aws.us_west_2
  }

  name_prefix = var.org_prefix
  account_id  = var.account_id

  vpc_peers = [
    {
      name                      = "${var.aws_region}-to-us-west-2"
      requester_vpc_id          = module.vpc.vpc_id
      requester_cidr            = var.vpc_cidr
      requester_route_table_ids = module.vpc.private_app_route_table_ids
      accepter_vpc_id           = var.secondary_vpc_id
      accepter_cidr             = var.secondary_vpc_cidr
      accepter_region           = "us-west-2"
      accepter_route_table_ids  = var.secondary_vpc_route_table_ids
    }
  ]

  enable_dns_resolution = true
  tags                  = local.common_tags
}

module "dns" {
  source = "../../modules/network/dns"

  name_prefix                = var.org_prefix
  internal_domain            = var.internal_domain
  network_vpc_id             = module.vpc.vpc_id
  resolver_subnet_ids        = module.vpc.private_app_subnet_ids
  resolver_security_group_id = module.vpc.app_security_group_id
  tags                       = local.common_tags
}

################################################################################
# Identity — IAM Baseline, MFA, SSO Permission Sets
################################################################################

module "iam_baseline" {
  source = "../../modules/identity/iam-baseline"

  break_glass_trusted_arns    = var.break_glass_trusted_arns
  security_sns_topic_arns     = [module.security_alerts.alerts_topic_arn]
  cloudtrail_log_group_name   = module.logging.cloudtrail_log_group_name
  tags                        = local.common_tags
}

module "mfa_enforcement" {
  source = "../../modules/identity/mfa-enforcement"

  organization_root_id = module.organization.organization_root_id
  tags                 = local.common_tags
}

module "sso" {
  source = "../../modules/identity/sso"
  tags   = local.common_tags
}

################################################################################
# Security — GuardDuty, Security Hub, Inspector, Config Rules
################################################################################

module "security_alerts" {
  # Inline SNS topic for security findings — used by GuardDuty + Break-Glass
  source = "../../modules/security/guardduty"

  audit_account_id = module.organization.audit_account_id
  kms_key_id       = module.kms.sns_key_id
  alert_email      = var.alert_email
  tags             = local.common_tags
}

module "security_hub" {
  source = "../../modules/security/security-hub"

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

  s3_kms_key_arn = module.kms.cloudtrail_key_arn
  tags           = local.common_tags
}

################################################################################
# Encryption — TLS Enforcement
################################################################################

module "tls_enforcement" {
  source = "../../modules/encryption/tls-enforcement"

  domain_name = var.domain_name
  tags        = local.common_tags
}

################################################################################
# Remediation Lambdas
################################################################################

module "remediate_s3" {
  source = "../../remediation/s3/block-public-access"

  kms_key_arn     = module.kms.secrets_key_arn
  alert_topic_arn = module.security_alerts.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_mfa" {
  source = "../../remediation/iam/mfa-gap-remediation"

  kms_key_arn     = module.kms.secrets_key_arn
  alert_topic_arn = module.security_alerts.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_ebs" {
  source = "../../remediation/ec2/encrypt-ebs"

  kms_key_arn     = module.kms.ebs_key_arn
  alert_topic_arn = module.security_alerts.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_sg" {
  source = "../../remediation/network/remove-sg-wildcard"

  kms_key_arn     = module.kms.s3_logs_key_arn
  alert_topic_arn = module.security_alerts.alerts_topic_arn
  tags            = local.common_tags
}

module "remediate_rds" {
  source = "../../remediation/rds/encrypt-rds"

  kms_key_arn     = module.kms.rds_key_arn
  alert_topic_arn = module.security_alerts.alerts_topic_arn
  tags            = local.common_tags
}
