variable "name_prefix" {
  description = "Short prefix for all Cloud WAN resource names (e.g., 'acme')."
  type        = string
}

variable "edge_locations" {
  description = "List of AWS regions where Cloud WAN edge locations will be provisioned."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "asn_ranges" {
  description = "BGP ASN ranges for the Cloud WAN core network. Must not overlap with on-premises ASNs."
  type        = list(string)
  default     = ["64512-64555"]
}

variable "vpc_attachments" {
  description = <<-EOT
    List of VPC attachments to create on the core network.
    Each object must have:
      name        — unique identifier used in resource names and tags
      vpc_arn     — ARN of the VPC to attach
      subnet_arns — list of subnet ARNs in the VPC (one per AZ, use private subnets)
    Optional:
      segment         — ForgeSegment value: "workload" (default), "shared-services", or "inspection"
      appliance_mode  — bool, enable for stateful inspection appliances (default false)
      ipv6_support    — bool (default false)
  EOT
  type = list(object({
    name           = string
    vpc_arn        = string
    subnet_arns    = list(string)
    segment        = optional(string, "workload")
    appliance_mode = optional(bool, false)
    ipv6_support   = optional(bool, false)
  }))
  default = []
}

variable "share_with_organization" {
  description = "When true, shares the core network via AWS RAM with the entire AWS Organization so spoke accounts can attach VPCs without explicit sharing."
  type        = bool
  default     = true
}

variable "organization_arn" {
  description = "ARN of the AWS Organization (required when share_with_organization = true)."
  type        = string
  default     = ""
}

variable "alarm_topic_arns" {
  description = "List of SNS topic ARNs to notify when attachment health alarms fire."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
