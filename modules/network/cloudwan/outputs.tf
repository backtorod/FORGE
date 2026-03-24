output "global_network_id" {
  description = "ID of the Cloud WAN Global Network."
  value       = aws_networkmanager_global_network.this.id
}

output "global_network_arn" {
  description = "ARN of the Cloud WAN Global Network."
  value       = aws_networkmanager_global_network.this.arn
}

output "core_network_id" {
  description = "ID of the Cloud WAN Core Network."
  value       = aws_networkmanager_core_network.this.id
}

output "core_network_arn" {
  description = "ARN of the Cloud WAN Core Network. Use this when attaching VPCs from spoke accounts."
  value       = aws_networkmanager_core_network.this.arn
}

output "attachment_ids" {
  description = "Map of attachment name → attachment ID for all VPC attachments created by this module."
  value       = { for k, v in aws_networkmanager_vpc_attachment.this : k => v.id }
}

output "ram_share_arn" {
  description = "ARN of the RAM resource share (present only when share_with_organization = true)."
  value       = var.share_with_organization ? aws_ram_resource_share.core_network[0].arn : null
}
