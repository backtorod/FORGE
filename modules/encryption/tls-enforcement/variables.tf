variable "domain_name" {
  description = "Publicly registered domain name in Route 53 (e.g. 'example.com'). Used to issue an ACM wildcard certificate (*.example.com) with automatic DNS validation."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
