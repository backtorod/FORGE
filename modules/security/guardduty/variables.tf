variable "audit_account_id" {
  description = "AWS Account ID of the Audit account (delegated GuardDuty admin)"
  type        = string
}

variable "finding_publishing_frequency" {
  description = "How often to publish GuardDuty findings (SIX_HOURS | ONE_HOUR | FIFTEEN_MINUTES)"
  type        = string
  default     = "ONE_HOUR"
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting SNS topics"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive GuardDuty/security alarm notifications. Leave empty to skip subscription."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
