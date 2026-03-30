variable "org_prefix" {
  description = "Short alphanumeric prefix for all resource names (e.g. 'acme-prod')."
  type        = string
}

variable "kms_key_arn" { type = string }

variable "alert_topic_arn" {
  description = "ARN of the SNS topic to notify when the remediation Lambda errors."
  type        = string
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "tags" {
  type    = map(string)
  default = {}
}
