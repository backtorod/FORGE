output "peering_connection_ids" {
  description = "Map of peering name → VPC peering connection ID."
  value       = { for k, v in aws_vpc_peering_connection.this : k => v.id }
}

output "peering_connection_statuses" {
  description = "Map of peering name → peering status (active, pending-acceptance, etc.)."
  value       = { for k, v in aws_vpc_peering_connection.this : k => v.accept_status }
}
