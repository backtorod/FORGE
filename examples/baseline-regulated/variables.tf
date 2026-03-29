variable "aws_region" {
  description = "Primary AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "org_prefix" {
  description = "Short prefix for your organization (e.g., 'acme'). Used in resource naming."
  type        = string
}

variable "allowed_regions" {
  description = "List of AWS regions that workloads are permitted to use."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "log_archive_account_email" {
  description = "Email address for the FORGE log-archive AWS account."
  type        = string
}

variable "audit_account_email" {
  description = "Email address for the FORGE audit AWS account."
  type        = string
}

variable "network_account_email" {
  description = "Email address for the FORGE network AWS account."
  type        = string
}

variable "shared_services_account_email" {
  description = "Email address for the FORGE shared-services AWS account."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the production VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (2 or 3)."
  type        = number
  default     = 2
}

variable "domain_name" {
  description = "Your primary domain name for ACM certificate issuance (e.g., example.com)."
  type        = string
}

variable "internal_domain" {
  description = "Private DNS domain name for Route 53 Resolver and internal hosted zones (e.g., corp.internal)."
  type        = string
  default     = "corp.internal"
}

variable "break_glass_trusted_arns" {
  description = "List of ARNs (users/roles) that can assume the break-glass role."
  type        = list(string)
}

variable "cost_center" {
  description = "Cost center tag value for billing attribution."
  type        = string
  default     = "engineering"
}

variable "account_id" {
  description = "AWS account ID of this deployment (used to build VPC/subnet ARNs for Cloud WAN attachments)."
  type        = string
}

variable "enable_cross_region_peering" {
  description = "Set to true to activate the VPC Peering module for cross-region intra-account connectivity."
  type        = bool
  default     = false
}

variable "secondary_vpc_id" {
  description = "VPC ID in the secondary region (required when enable_cross_region_peering = true)."
  type        = string
  default     = ""
}

variable "secondary_vpc_cidr" {
  description = "CIDR block of the secondary VPC (required when enable_cross_region_peering = true)."
  type        = string
  default     = ""
}

variable "secondary_vpc_route_table_ids" {
  description = "Route table IDs in the secondary VPC to inject return routes into (required when enable_cross_region_peering = true)."
  type        = list(string)
  default     = []
}

variable "workload_account_ids" {
  description = "List of AWS account IDs to enroll in Inspector v2 scanning (all workload/member accounts)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
