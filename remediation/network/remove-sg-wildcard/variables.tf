variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Lambda environment variables."
  type        = string
}

variable "alert_topic_arn" {
  description = "ARN of the SNS topic to notify when the remediation Lambda errors."
  type        = string
}

variable "blocked_ports" {
  description = "Comma-separated list of ports that must not be exposed to 0.0.0.0/0 or ::/0."
  type        = string
  default     = "22,3389,3306,5432,1433,27017,6379,11211"
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
