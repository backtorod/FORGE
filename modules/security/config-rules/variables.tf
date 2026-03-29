variable "s3_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the dedicated Config delivery S3 bucket. Must allow config.amazonaws.com as a service principal."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
