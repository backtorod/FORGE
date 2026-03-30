variable "org_prefix" {
  description = "Short prefix applied to all permission set names (e.g. 'acme')"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
