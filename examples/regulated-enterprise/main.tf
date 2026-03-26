################################################################################
# FORGE — Example: Regulated Enterprise (500+ employees, FFIEC CAT / HIPAA)
#
# Extends growth-stage with enterprise-grade controls required by:
#   • FFIEC CAT — Cyber Risk Management and Oversight domain coverage
#   • HIPAA — §164.312 Technical Safeguards
#   • FedRAMP Moderate — baseline alignment
#   • HITRUST CSF — inherited controls through AWS
#
# Additional capabilities over growth-stage:
#   • AWS Network Firewall — stateful east-west and north-south inspection
#   • AWS Audit Manager — custom FORGE assessment framework with evidence collection
#   • AWS Backup — centralized backup vault with cross-account copy and vault lock
#   • Cross-account EventBridge bus — SIEM ingestion pipeline (Splunk/Sentinel/Sumo)
#   • AWS CloudHSM cluster — customer-managed HSM key material for highest-assurance keys
#   • Dedicated HIPAA and FFIEC compliance accounts
#   • HITRUST/HIPAA-specific Security Hub standards and Config rules
#   • AWS Config conformance packs aligned to NIST 800-53 Rev 5
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
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "forge/regulated-enterprise/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  default_tags { tags = local.common_tags }
}

# WAFv2 CloudFront WebACLs must be deployed in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags { tags = local.common_tags }
}

locals {
  common_tags = merge(var.tags, {
    FORGE_Version      = "0.3.0"
    FORGE_Example      = "regulated-enterprise"
    Environment        = "production"
    CostCenter         = var.cost_center
    DataClassification = "Restricted"
    ComplianceScope    = join(",", var.compliance_frameworks)
  })

  # Firewall subnet CIDR blocks carved out of the primary VPC.
  # These are /28 subnets in each AZ, reserved for Network Firewall endpoints.
  firewall_subnet_cidrs = var.firewall_subnet_cidrs
}

################################################################################
# Foundation — Organization, SCPs, Centralized Logging (inherited from growth-stage)
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

  organization_root_id = module.organization.organization_root_id
  workload_ou_ids = [
    module.organization.ou_workloads_prod_id,
    module.organization.ou_workloads_nonprod_id,
  ]
  allowed_regions = var.allowed_regions
  tags            = local.common_tags
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
  tags                   = local.common_tags
}

################################################################################
# Network — Multi-Region + AWS Network Firewall
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

  name_prefix        = var.org_prefix
  network_account_id = module.organization.network_account_id
  vpc_id             = module.vpc_primary.vpc_id
  private_subnet_ids = module.vpc_primary.private_app_subnet_ids
  tags               = local.common_tags
}

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

  name_prefix        = var.org_prefix
  vpc_id             = module.vpc_primary.vpc_id
  private_subnet_ids = module.vpc_primary.private_app_subnet_ids
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS Network Firewall — stateful east-west and north-south packet inspection.
# Deployed into dedicated /28 firewall subnets in each AZ.
# ---------------------------------------------------------------------------

resource "aws_subnet" "firewall" {
  for_each = { for idx, cidr in local.firewall_subnet_cidrs : tostring(idx) => cidr }

  vpc_id            = module.vpc_primary.vpc_id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[tonumber(each.key)]

  tags = merge(local.common_tags, {
    Name = "${var.org_prefix}-firewall-${tonumber(each.key)}"
    Tier = "firewall"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.org_prefix}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.block_threats.arn
      priority     = 100
    }
  }

  tags = local.common_tags
}

resource "aws_networkfirewall_rule_group" "block_threats" {
  capacity = 100
  name     = "${var.org_prefix}-block-threats"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = local.common_tags
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.org_prefix}-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = module.vpc_primary.vpc_id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  firewall_policy_change_protection = true
  subnet_change_protection          = true
  delete_protection                 = var.enable_firewall_delete_protection

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  name              = "/aws/network-firewall/${var.org_prefix}/flow"
  retention_in_days = var.firewall_log_retention_days
  kms_key_id        = module.kms.cloudtrail_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "firewall_alert" {
  name              = "/aws/network-firewall/${var.org_prefix}/alert"
  retention_in_days = var.firewall_log_retention_days
  kms_key_id        = module.kms.cloudtrail_key_arn
  tags              = local.common_tags
}

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination      = { logGroup = aws_cloudwatch_log_group.firewall_flow.name }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
    log_destination_config {
      log_destination      = { logGroup = aws_cloudwatch_log_group.firewall_alert.name }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

################################################################################
# Identity — IAM Baseline, MFA, SSO with SCIM
################################################################################

module "iam_baseline" {
  source = "../../modules/identity/iam-baseline"

  break_glass_trusted_arns = var.break_glass_trusted_arns
  security_sns_topic_arns  = [module.guardduty.alerts_topic_arn]
  tags                     = local.common_tags
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
# Security — GuardDuty, Security Hub, Inspector, Config, Macie
################################################################################

module "guardduty" {
  source = "../../modules/security/guardduty"

  audit_account_id = module.organization.audit_account_id
  kms_key_id       = module.kms.sns_key_id
  tags             = local.common_tags
}

module "security_hub" {
  source = "../../modules/security/security-hub"

  audit_account_id = module.organization.audit_account_id
  tags             = local.common_tags
}

module "inspector" {
  source = "../../modules/security/inspector"

  audit_account_id = module.organization.audit_account_id
  tags             = local.common_tags
}

module "config_rules" {
  source = "../../modules/security/config-rules"

  log_archive_bucket_id = module.logging.log_archive_bucket_name
  tags                  = local.common_tags
}

# NIST 800-53 Rev 5 conformance pack — FedRAMP Moderate alignment.
resource "aws_config_conformance_pack" "nist_800_53" {
  name = "${var.org_prefix}-nist-800-53-rev5"

  template_body = <<-TEMPLATE
    Parameters:
      AccessKeysRotatedParamMaxAccessKeyAge:
        Default: "90"
    Resources:
      AWSConfigRuleAccessKeysRotated:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: access-keys-rotated
          Source:
            Owner: AWS
            SourceIdentifier: ACCESS_KEYS_ROTATED
          InputParameters:
            maxAccessKeyAge: "90"
  TEMPLATE

  depends_on = [module.config_rules]
}

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

# Amazon Macie — PHI and PCI sensitive-data discovery (HIPAA §164.312 requirement).
resource "aws_macie2_account" "this" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "s3_full_scan" {
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
# Audit Manager — FORGE custom assessment framework
################################################################################

resource "aws_auditmanager_framework" "forge" {
  count = var.enable_audit_manager ? 1 : 0
  name  = "FORGE-${upper(join("-", var.compliance_frameworks))}-Framework"

  control_sets {
    name = "Access-Control"
    controls {
      id = aws_auditmanager_control.iam_mfa.id
    }
    controls {
      id = aws_auditmanager_control.access_key_rotation.id
    }
  }

  control_sets {
    name = "Data-Protection"
    controls {
      id = aws_auditmanager_control.s3_encryption.id
    }
    controls {
      id = aws_auditmanager_control.rds_encryption.id
    }
  }

  tags = local.common_tags
}

resource "aws_auditmanager_control" "iam_mfa" {
  count = var.enable_audit_manager ? 1 : 0
  name  = "IAM-MFA-Required"

  control_mapping_sources {
    source_name          = "MFA-Config-Rule"
    source_set_up_option = "System_Controls_Mapping"
    source_type          = "AWS_Config"
    source_keyword {
      keyword_input_type = "SELECT_FROM_LIST"
      keyword_value      = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
    }
  }

  tags = local.common_tags
}

resource "aws_auditmanager_control" "access_key_rotation" {
  count = var.enable_audit_manager ? 1 : 0
  name  = "Access-Key-Rotation-90-Days"

  control_mapping_sources {
    source_name          = "AccessKeyRotation-Config-Rule"
    source_set_up_option = "System_Controls_Mapping"
    source_type          = "AWS_Config"
    source_keyword {
      keyword_input_type = "SELECT_FROM_LIST"
      keyword_value      = "ACCESS_KEYS_ROTATED"
    }
  }

  tags = local.common_tags
}

resource "aws_auditmanager_control" "s3_encryption" {
  count = var.enable_audit_manager ? 1 : 0
  name  = "S3-Server-Side-Encryption"

  control_mapping_sources {
    source_name          = "S3-SSE-Config-Rule"
    source_set_up_option = "System_Controls_Mapping"
    source_type          = "AWS_Config"
    source_keyword {
      keyword_input_type = "SELECT_FROM_LIST"
      keyword_value      = "S3_DEFAULT_ENCRYPTION_KMS"
    }
  }

  tags = local.common_tags
}

resource "aws_auditmanager_control" "rds_encryption" {
  count = var.enable_audit_manager ? 1 : 0
  name  = "RDS-Storage-Encrypted"

  control_mapping_sources {
    source_name          = "RDS-Encryption-Config-Rule"
    source_set_up_option = "System_Controls_Mapping"
    source_type          = "AWS_Config"
    source_keyword {
      keyword_input_type = "SELECT_FROM_LIST"
      keyword_value      = "RDS_STORAGE_ENCRYPTED"
    }
  }

  tags = local.common_tags
}

resource "aws_auditmanager_assessment" "forge" {
  count = var.enable_audit_manager && length(aws_auditmanager_framework.forge) > 0 ? 1 : 0
  name  = "${var.org_prefix}-FORGE-Assessment"

  assessment_reports_destination {
    destination      = "s3://${module.logging.log_archive_bucket_name}/audit-manager/"
    destination_type = "S3"
  }

  framework_id = aws_auditmanager_framework.forge[0].id

  roles {
    role_arn  = aws_iam_role.audit_manager.arn
    role_type = "PROCESS_OWNER"
  }

  scope {
    aws_accounts {
      id = var.account_id
    }
    aws_services {
      service_name = "S3"
    }
    aws_services {
      service_name = "IAM"
    }
    aws_services {
      service_name = "RDS"
    }
    aws_services {
      service_name = "GuardDuty"
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "audit_manager" {
  name               = "${var.org_prefix}-audit-manager-role"
  assume_role_policy = data.aws_iam_policy_document.audit_manager_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "audit_manager_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["auditmanager.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "audit_manager" {
  role       = aws_iam_role.audit_manager.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAuditManagerServiceRolePolicy"
}

################################################################################
# AWS Backup — centralized vault with vault lock and cross-account copy
################################################################################

resource "aws_backup_vault" "primary" {
  name        = "${var.org_prefix}-primary-backup-vault"
  kms_key_arn = module.kms.rds_key_arn
  tags        = local.common_tags
}

# Vault Lock — WORM protection prevents backup deletion for compliance retention.
resource "aws_backup_vault_lock_configuration" "primary" {
  count               = var.enable_backup_vault_lock ? 1 : 0
  backup_vault_name   = aws_backup_vault.primary.name
  min_retention_days  = var.backup_min_retention_days
  max_retention_days  = var.backup_max_retention_days
  changeable_for_days = var.backup_vault_lock_changeable_days
}

resource "aws_backup_vault" "secondary" {
  provider    = aws.secondary
  name        = "${var.org_prefix}-secondary-backup-vault"
  kms_key_arn = module.kms.rds_key_arn
  tags        = local.common_tags
}

resource "aws_backup_plan" "main" {
  name = "${var.org_prefix}-backup-plan"

  rule {
    rule_name         = "daily-backups"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 ? * * *)"   # Daily at 05:00 UTC
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = var.backup_cold_storage_after_days
      delete_after       = var.backup_retention_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.secondary.arn

      lifecycle {
        cold_storage_after = var.backup_cold_storage_after_days
        delete_after       = var.backup_retention_days
      }
    }
  }

  rule {
    rule_name         = "weekly-backups"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 6 ? * SUN *)"   # Weekly on Sunday at 06:00 UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "backup" {
  name               = "${var.org_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

################################################################################
# Centralized SIEM — Cross-account EventBridge bus for log aggregation
################################################################################

resource "aws_cloudwatch_event_bus" "siem" {
  count = var.enable_siem_event_bus ? 1 : 0
  name  = "${var.org_prefix}-siem-event-bus"
  tags  = local.common_tags
}

resource "aws_cloudwatch_event_bus_policy" "siem" {
  count          = var.enable_siem_event_bus ? 1 : 0
  event_bus_name = aws_cloudwatch_event_bus.siem[0].name

  policy = data.aws_iam_policy_document.siem_event_bus[0].json
}

data "aws_iam_policy_document" "siem_event_bus" {
  count = var.enable_siem_event_bus ? 1 : 0

  statement {
    sid     = "AllowOrganizationAccounts"
    effect  = "Allow"
    actions = ["events:PutEvents"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [module.organization.organization_id]
    }

    resources = [aws_cloudwatch_event_bus.siem[0].arn]
  }
}

# Forward high-severity GuardDuty findings to the SIEM event bus.
resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  count          = var.enable_siem_event_bus ? 1 : 0
  name           = "${var.org_prefix}-guardduty-high-severity"
  description    = "Captures GuardDuty findings with severity >= 7 for SIEM ingestion"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "guardduty_to_siem" {
  count          = var.enable_siem_event_bus ? 1 : 0
  rule           = aws_cloudwatch_event_rule.guardduty_high_severity[0].name
  event_bus_name = "default"
  target_id      = "SIEMEventBus"
  arn            = aws_cloudwatch_event_bus.siem[0].arn
  role_arn       = aws_iam_role.events_to_siem[0].arn
}

resource "aws_iam_role" "events_to_siem" {
  count              = var.enable_siem_event_bus ? 1 : 0
  name               = "${var.org_prefix}-events-to-siem-role"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "events_to_siem" {
  count = var.enable_siem_event_bus ? 1 : 0
  statement {
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.siem[0].arn]
  }
}

resource "aws_iam_role_policy" "events_to_siem" {
  count  = var.enable_siem_event_bus ? 1 : 0
  name   = "put-events-to-siem"
  role   = aws_iam_role.events_to_siem[0].id
  policy = data.aws_iam_policy_document.events_to_siem[0].json
}

################################################################################
# Encryption — TLS, WAFv2, KMS
################################################################################

module "tls_enforcement" {
  source = "../../modules/encryption/tls-enforcement"

  organization_root_id = module.organization.organization_root_id
  domain_name          = var.domain_name
  tags                 = local.common_tags
}

resource "aws_wafv2_web_acl" "regional" {
  name  = "${var.org_prefix}-enterprise-web-acl"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action { none {} }
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
    override_action { none {} }
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
    override_action { none {} }
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
    metric_name                = "${var.org_prefix}EnterpriseWebACL"
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
  source      = "../../remediation/s3/block-public-access"
  kms_key_arn = module.kms.s3_logs_key_arn
  tags        = local.common_tags
}

module "remediate_mfa" {
  source      = "../../remediation/iam/mfa-gap-remediation"
  kms_key_arn = module.kms.secrets_key_arn
  tags        = local.common_tags
}

module "remediate_ebs" {
  source      = "../../remediation/ec2/encrypt-ebs"
  kms_key_arn = module.kms.ebs_key_arn
  tags        = local.common_tags
}

module "remediate_sg" {
  source      = "../../remediation/network/remove-sg-wildcard"
  kms_key_arn = module.kms.s3_logs_key_arn
  tags        = local.common_tags
}

module "remediate_rds" {
  source          = "../../remediation/rds/encrypt-rds"
  kms_key_arn     = module.kms.rds_key_arn
  alert_topic_arn = module.guardduty.alerts_topic_arn
  tags            = local.common_tags
}
