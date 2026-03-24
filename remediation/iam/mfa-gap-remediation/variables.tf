variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Lambda environment variables."
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
