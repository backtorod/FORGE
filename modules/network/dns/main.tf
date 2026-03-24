################################################################################
# FORGE — Network: Centralized DNS (Route 53 Resolver)
# All accounts resolve DNS through the Network account
# TODO (v1.1): Add DNS Firewall rules for malicious domain blocking
################################################################################

# Private hosted zone for internal service discovery
resource "aws_route53_zone" "internal" {
  name    = var.internal_domain
  comment = "FORGE internal DNS — managed by IaC"

  vpc {
    vpc_id = var.network_vpc_id
  }

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-internal-zone"
    FORGE_Control = "NET-020"
  })
}

# Resolver inbound endpoint (allows workload accounts to query Network account DNS)
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${var.name_prefix}-resolver-inbound"
  direction = "INBOUND"

  security_group_ids = [var.resolver_security_group_id]

  dynamic "ip_address" {
    for_each = var.resolver_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-resolver-inbound" })
}

# Resolver outbound endpoint (for forwarding rules to on-premises DNS)
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "${var.name_prefix}-resolver-outbound"
  direction = "OUTBOUND"

  security_group_ids = [var.resolver_security_group_id]

  dynamic "ip_address" {
    for_each = var.resolver_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-resolver-outbound" })
}
