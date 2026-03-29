variable "log_archive_account_id" {
  description = "AWS Account ID of the Log Archive account"
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID (for bucket policy SourceOrgID condition)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt log objects"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs in S3 (minimum 2555 for FFIEC 7-year requirement)"
  type        = number
  default     = 2555

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "FORGE requires at least 365 days of log retention. FFIEC requires 2555 (7 years)."
  }
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs to notify when the root account usage alarm fires. Pass the security alerts topic ARN here."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all logging resources"
  type        = map(string)
  default     = {}
}
