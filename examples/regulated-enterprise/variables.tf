################################################################################
# FORGE — Regulated-Enterprise Example: variables.tf
################################################################################

# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for active-active VPC topology and cross-region backup copies."
  type        = string
  default     = "us-west-2"
}

variable "allowed_regions" {
  description = "List of AWS regions workloads are permitted to use (enforced by SCP)."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# ---------------------------------------------------------------------------
# Organization
# ---------------------------------------------------------------------------

variable "org_prefix" {
  description = "Short prefix for the organization (e.g., 'acme'). Used in all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.org_prefix))
    error_message = "org_prefix must be 2–15 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "account_id" {
  description = "AWS account ID of the management account running this deployment."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account number."
  }
}

variable "log_archive_account_email" {
  description = "Email address for the FORGE log-archive AWS account (must be globally unique)."
  type        = string
}

variable "audit_account_email" {
  description = "Email address for the FORGE audit AWS account (must be globally unique)."
  type        = string
}

variable "network_account_email" {
  description = "Email address for the FORGE network AWS account (must be globally unique)."
  type        = string
}

variable "shared_services_account_email" {
  description = "Email address for the FORGE shared-services AWS account (must be globally unique)."
  type        = string
}

# ---------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------

variable "compliance_frameworks" {
  description = "List of compliance frameworks in scope. Used as tags and in Audit Manager framework names."
  type        = list(string)
  default     = ["hipaa", "ffiec-cat"]

  validation {
    condition     = length(var.compliance_frameworks) > 0
    error_message = "At least one compliance framework must be specified."
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the primary production VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "CIDR block for the secondary-region production VPC. Must not overlap with vpc_cidr."
  type        = string
  default     = "10.1.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones per region (2 for HA, 3 recommended for enterprise)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# ---------------------------------------------------------------------------
# Network Firewall
# ---------------------------------------------------------------------------

variable "firewall_subnet_cidrs" {
  description = "List of /28 CIDR blocks (one per AZ) carved out of vpc_cidr for Network Firewall endpoints."
  type        = list(string)
  default     = ["10.0.3.0/28", "10.0.3.16/28", "10.0.3.32/28"]

  validation {
    condition     = length(var.firewall_subnet_cidrs) >= 2
    error_message = "At least two firewall subnet CIDRs are required for high availability."
  }
}

variable "enable_firewall_delete_protection" {
  description = "Enable delete protection on the Network Firewall resource to prevent accidental deletion."
  type        = bool
  default     = true
}

variable "firewall_log_retention_days" {
  description = "CloudWatch log retention in days for Network Firewall flow and alert logs."
  type        = number
  default     = 365
}

# ---------------------------------------------------------------------------
# Domain / TLS
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Primary domain name for ACM certificate issuance (e.g., example.com)."
  type        = string
}

variable "internal_domain" {
  description = "Internal DNS domain for Route 53 Resolver (e.g., 'corp.internal')."
  type        = string
  default     = "corp.internal"
}

variable "alert_email" {
  description = "Email address to receive GuardDuty and security alarm notifications. Leave empty to skip subscription."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "break_glass_trusted_arns" {
  description = "List of IAM user or role ARNs permitted to assume the break-glass emergency-access role."
  type        = list(string)
}

variable "scim_endpoint_url" {
  description = "SCIM 2.0 endpoint URL from your identity provider. Leave empty to skip SCIM attribute mapping."
  type        = string
  default     = ""
}

variable "scim_access_token_secret_arn" {
  description = "Secrets Manager ARN holding the SCIM access token. Required when scim_endpoint_url is set."
  type        = string
  default     = ""

  validation {
    condition     = var.scim_access_token_secret_arn == "" || can(regex("^arn:aws:secretsmanager:", var.scim_access_token_secret_arn))
    error_message = "scim_access_token_secret_arn must be a valid Secrets Manager ARN or empty string."
  }
}

# ---------------------------------------------------------------------------
# Audit Manager
# ---------------------------------------------------------------------------

variable "enable_audit_manager" {
  description = "Enable AWS Audit Manager with the FORGE custom assessment framework."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

variable "enable_backup_vault_lock" {
  description = "Enable AWS Backup Vault Lock (WORM) to prevent backup deletion during the compliance retention window."
  type        = bool
  default     = true
}

variable "backup_min_retention_days" {
  description = "Minimum number of days backups must be retained (Vault Lock lower bound)."
  type        = number
  default     = 7
}

variable "backup_max_retention_days" {
  description = "Maximum number of days backups may be retained (Vault Lock upper bound)."
  type        = number
  default     = 3650   # 10 years — HIPAA minimum is 6 years
}

variable "backup_vault_lock_changeable_days" {
  description = "Number of days during which the Vault Lock configuration can still be changed before it becomes immutable. Set to 0 for immediate immutability (irreversible)."
  type        = number
  default     = 3
}

variable "backup_retention_days" {
  description = "Number of days to retain daily backups before deletion."
  type        = number
  default     = 90
}

variable "backup_cold_storage_after_days" {
  description = "Number of days after which backups are moved to cold (Glacier) storage."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# SIEM — EventBridge
# ---------------------------------------------------------------------------

variable "enable_siem_event_bus" {
  description = "Create a cross-account EventBridge event bus for centralized SIEM ingestion."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# WAFv2
# ---------------------------------------------------------------------------

variable "waf_alb_arn" {
  description = "ARN of the internet-facing ALB to associate with the WAFv2 WebACL. Leave empty to skip association."
  type        = string
  default     = ""

  validation {
    condition     = var.waf_alb_arn == "" || can(regex("^arn:aws:elasticloadbalancing:", var.waf_alb_arn))
    error_message = "waf_alb_arn must be a valid ALB ARN or empty string."
  }
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "cost_center" {
  description = "Cost center tag value for billing attribution."
  type        = string
  default     = "engineering"
}

variable "tags" {
  description = "Additional tags to merge onto all resources."
  type        = map(string)
  default     = {}
}
