variable "name_prefix" {
  type = string
}

variable "amazon_side_asn" {
  description = "Private ASN for the Transit Gateway BGP session"
  type        = number
  default     = 64512
}

variable "network_vpc_id" {
  description = "VPC ID in the Network account to attach to the TGW"
  type        = string
}

variable "network_vpc_subnet_ids" {
  description = "Subnet IDs in the Network account VPC for the TGW attachment"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
