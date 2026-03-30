variable "org_prefix" {
  description = "Short alphanumeric prefix for all resource names (e.g. 'acme-prod')."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Lambda environment variables."
  type        = string
}

variable "alert_topic_arn" {
  description = "ARN of the SNS topic that receives RDS encryption violation alerts."
  type        = string
}

variable "log_level" {
  description = "Lambda log level (DEBUG, INFO, WARNING, ERROR)."
  type        = string
  default     = "INFO"
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
