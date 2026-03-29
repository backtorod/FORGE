variable "kms_key_arn" { type = string }
variable "log_level" {
  type    = string
  default = "INFO"
}

variable "tags" {
  type    = map(string)
  default = {}
}
