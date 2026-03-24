variable "log_archive_bucket_name" {
  description = "S3 bucket name in Log Archive account for AWS Config delivery"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
