variable "org_prefix" {
  description = "Short alphanumeric prefix for all resource names (e.g. 'acme-prod'). Used for KMS alias names."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period before KMS key is deleted (7–30 days)"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "multi_region_keys" {
  description = "Create multi-region KMS keys (required for cross-region disaster recovery)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
