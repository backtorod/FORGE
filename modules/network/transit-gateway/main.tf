################################################################################
# FORGE — Network: Transit Gateway
# Centralized network hub connecting all workload VPCs
# TODO (v1.1): Add cross-account RAM sharing, Direct Connect integration
################################################################################

resource "aws_ec2_transit_gateway" "this" {
  description                     = "FORGE centralized transit gateway"
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = "disable"  # Explicit approval required
  default_route_table_association = "disable"  # Managed route tables only
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-tgw"
    FORGE_Control = "NET-010"
    NIST_Control  = "SC-7"
  })
}

# Attach Network Account VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "network" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.network_vpc_id
  subnet_ids         = var.network_vpc_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw-attach-network" })
}

# Separate route tables per OU for traffic isolation
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name_prefix}-tgw-rt-prod" })
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(var.tags, { Name = "${var.name_prefix}-tgw-rt-nonprod" })
}
