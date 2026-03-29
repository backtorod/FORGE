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
