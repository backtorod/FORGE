variable "name_prefix" {
  description = "Prefix for all resource names (e.g. 'acme-prod')"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to deploy across (2 minimum for HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "log_archive_bucket_arn" {
  description = "ARN of the centralized S3 log archive bucket for VPC flow logs"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all VPC resources"
  type        = map(string)
  default     = {}
}
