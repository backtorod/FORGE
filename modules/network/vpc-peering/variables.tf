variable "name_prefix" {
  description = "Short prefix for peering resource names and tags."
  type        = string
}

variable "account_id" {
  description = "AWS account ID that owns all peered VPCs. Both sides must be in this account."
  type        = string
}

variable "vpc_peers" {
  description = <<-EOT
    List of VPC pairs to peer. Each object describes one peering connection.

    Required fields:
      name                    — unique key used in resource names (no spaces)
      requester_vpc_id        — VPC ID on the requester (primary) side
      requester_cidr          — CIDR of the requester VPC (used for accepter routes)
      requester_route_table_ids — list of route table IDs in the requester VPC to update
      accepter_vpc_id         — VPC ID on the accepter side
      accepter_cidr           — CIDR of the accepter VPC (used for requester routes)
      accepter_region         — AWS region of the accepter VPC
      accepter_route_table_ids  — list of route table IDs in the accepter VPC to update

    Example:
      {
        name                      = "us-east-1-to-eu-west-1"
        requester_vpc_id          = "vpc-0abc123"
        requester_cidr            = "10.0.0.0/16"
        requester_route_table_ids = ["rtb-0aaa111", "rtb-0bbb222"]
        accepter_vpc_id           = "vpc-0def456"
        accepter_cidr             = "10.1.0.0/16"
        accepter_region           = "eu-west-1"
        accepter_route_table_ids  = ["rtb-0ccc333"]
      }
  EOT
  type = list(object({
    name                      = string
    requester_vpc_id          = string
    requester_cidr            = string
    requester_route_table_ids = list(string)
    accepter_vpc_id           = string
    accepter_cidr             = string
    accepter_region           = string
    accepter_route_table_ids  = list(string)
  }))
}

variable "enable_dns_resolution" {
  description = "When true, enables private DNS resolution across each peering link. Requires enableDnsHostnames on both VPCs."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
