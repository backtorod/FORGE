variable "name_prefix" { type = string }
variable "internal_domain" {
  description = "Internal domain name (e.g. 'corp.internal')"
  type        = string
}
variable "network_vpc_id" { type = string }
variable "resolver_subnet_ids" { type = list(string) }
variable "resolver_security_group_id" { type = string }
variable "tags" { type = map(string); default = {} }
