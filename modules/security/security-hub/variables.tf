variable "audit_account_id" { type = string }

variable "org_prefix" {
  description = "Short alphanumeric prefix for all resource names (e.g. 'acme-prod')."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
