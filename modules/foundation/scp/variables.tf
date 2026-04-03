variable "org_prefix" {
  description = "Short prefix applied to all SCP policy names (e.g. 'acme')"
  type        = string
}

variable "organization_root_id" {
  description = "The root ID of the AWS Organization"
  type        = string
}

variable "workload_ou_ids" {
  description = "List of workload OU IDs to attach workload-specific SCPs to"
  type        = list(string)
}

variable "allowed_regions" {
  description = "List of AWS regions that accounts are permitted to operate in"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "tags" {
  description = "Common tags applied to all SCP resources"
  type        = map(string)
  default     = {}
}
