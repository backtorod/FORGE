variable "break_glass_trusted_arns" {
  description = "List of IAM ARNs allowed to assume the break-glass role (e.g. specific IAM users)"
  type        = list(string)
}

variable "security_sns_topic_arns" {
  description = "List of SNS topic ARNs to notify when break-glass role is used"
  type        = list(string)
  default     = []
}

variable "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch Logs log group receiving CloudTrail events (used for break-glass metric filter)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
