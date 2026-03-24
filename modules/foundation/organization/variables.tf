variable "org_prefix" {
  description = "Short prefix applied to all account names (e.g. 'acme')"
  type        = string
}

variable "log_archive_account_email" {
  description = "Unique email address for the Log Archive account"
  type        = string
}

variable "audit_account_email" {
  description = "Unique email address for the Audit account"
  type        = string
}

variable "network_account_email" {
  description = "Unique email address for the Network account"
  type        = string
}

variable "shared_services_account_email" {
  description = "Unique email address for the Shared Services account"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all organization-level resources"
  type        = map(string)
  default     = {}
}
