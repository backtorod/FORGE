output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (ALB tier)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs (compute tier)"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "List of private data subnet IDs (database tier)"
  value       = aws_subnet.private_data[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB tier"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for the application tier"
  value       = aws_security_group.app.id
}

output "data_security_group_id" {
  description = "Security group ID for the data tier"
  value       = aws_security_group.data.id
}

output "private_app_route_table_ids" {
  description = "List of route table IDs for the private app tier (one per AZ)"
  value       = aws_route_table.private_app[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IPs of the NAT Gateways (for allowlisting)"
  value       = aws_eip.nat[*].public_ip
}
