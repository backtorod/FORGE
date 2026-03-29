################################################################################
# FORGE — Growth-Stage Example: Variables
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
  description = "Secondary AWS region for the active-active VPC topology."
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

variable "account_id" {
  description = "AWS account ID of the management account running this deployment (used to build VPC/subnet ARNs for Cloud WAN)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account number."
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
  description = "Number of Availability Zones per region (2 for HA, 3 for high-throughput workloads)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# ---------------------------------------------------------------------------
# Domain / TLS
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Primary domain name for ACM certificate issuance (e.g., example.com)."
  type        = string
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "break_glass_trusted_arns" {
  description = "List of IAM user or role ARNs permitted to assume the break-glass emergency-access role."
  type        = list(string)
}

variable "scim_endpoint_url" {
  description = "SCIM 2.0 endpoint URL provided by your identity provider. Leave empty to skip SCIM attribute mapping."
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
# Macie
# ---------------------------------------------------------------------------

variable "enable_macie" {
  description = "Enable Amazon Macie for S3 sensitive-data (PII/PCI/PHI) discovery."
  type        = bool
  default     = true
}

variable "macie_finding_publishing_frequency" {
  description = "Frequency at which Macie publishes updated findings (FIFTEEN_MINUTES | ONE_HOUR | SIX_HOURS)."
  type        = string
  default     = "ONE_HOUR"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.macie_finding_publishing_frequency)
    error_message = "macie_finding_publishing_frequency must be one of: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

# ---------------------------------------------------------------------------
# WAFv2 / Shield
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
