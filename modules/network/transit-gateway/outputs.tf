output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "route_table_prod_id" {
  description = "Route table ID for production workload attachments"
  value       = aws_ec2_transit_gateway_route_table.prod.id
}

output "route_table_nonprod_id" {
  description = "Route table ID for non-production workload attachments"
  value       = aws_ec2_transit_gateway_route_table.nonprod.id
}
