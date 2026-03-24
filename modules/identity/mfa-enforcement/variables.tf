variable "organization_root_id" {
  description = "AWS Organization root ID to attach the MFA enforcement SCP"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
