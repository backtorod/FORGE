################################################################################
# FORGE — Network: Cross-Region VPC Peering
#
# Use this module when a SINGLE AWS account owns VPCs in multiple regions
# and those VPCs must be treated as one logical network entity — i.e. private
# reachability between them without hairpinning through a central hub.
#
# Design intent (vs. Cloud WAN):
#   Cloud WAN  — org-wide multi-account backbone (the default for FORGE)
#   VPC Peering — intra-account cross-region mesh, complements Cloud WAN for
#                 workloads that explicitly own resources in >1 region and need
#                 direct, low-latency paths without transitive routing.
#
# What this module does:
#   1. Creates VPC peering connections between every pair in var.vpc_peers
#      (requester side always in var.requester_region).
#   2. Accepts the peering on the accepter side (same account, different region)
#      via the aliased accepter provider.
#   3. Adds routes in BOTH directions so subnets in each VPC can reach the other.
#   4. Optionally enables DNS resolution across the peering link.
#
# NOTE: VPC peering is non-transitive. If you need A→B→C routing, use Cloud WAN.
#       VPC peering is limited to 125 active peerings per VPC (AWS limit).
#
# PROVIDER REQUIREMENT: Callers must pass a provider aliased to the accepter
# region via the providers map, e.g.:
#
#   provider "aws" {
#     alias  = "eu_west_1"
#     region = "eu-west-1"
#   }
#   module "vpc_peering" {
#     ...
#     providers = {
#       aws          = aws
#       aws.accepter = aws.eu_west_1
#     }
#   }
#
# If you need to peer with more than one accepter region, instantiate this
# module once per accepter region.
################################################################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.accepter]
    }
  }
}

###############################################################################
# Peering Connections (requester side)
###############################################################################

resource "aws_vpc_peering_connection" "this" {
  for_each = { for p in var.vpc_peers : p.name => p }

  vpc_id        = each.value.requester_vpc_id
  peer_vpc_id   = each.value.accepter_vpc_id
  peer_region   = each.value.accepter_region
  peer_owner_id = var.account_id  # same account

  # auto_accept only works within the same region; cross-region requires explicit accept below
  auto_accept = false

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-peer-${each.key}"
    FORGE_Control = "FORGE-NET-005"
    Side          = "requester"
  })
}

###############################################################################
# Accepter side — must use a provider aliased to the accepter region
# Callers must pass in accepter_providers matching each peer's accepter_region.
###############################################################################

resource "aws_vpc_peering_connection_accepter" "this" {
  for_each = { for p in var.vpc_peers : p.name => p }

  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.key].id
  auto_accept               = true

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-peer-${each.key}-accepter"
    FORGE_Control = "FORGE-NET-005"
    Side          = "accepter"
  })
}

###############################################################################
# DNS resolution across the peering link
###############################################################################

resource "aws_vpc_peering_connection_options" "requester" {
  for_each                  = var.enable_dns_resolution ? { for p in var.vpc_peers : p.name => p } : {}
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.key].id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

resource "aws_vpc_peering_connection_options" "accepter" {
  for_each = var.enable_dns_resolution ? { for p in var.vpc_peers : p.name => p } : {}

  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.key].id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

###############################################################################
# Routes — requester side
# Adds a route in each specified requester route table pointing at the peering.
###############################################################################

locals {
  # Flatten: for each peer × each requester_route_table_id → one route entry
  requester_routes = flatten([
    for p in var.vpc_peers : [
      for rt_id in p.requester_route_table_ids : {
        key                   = "${p.name}-req-${rt_id}"
        peer_name             = p.name
        route_table_id        = rt_id
        destination_cidr      = p.accepter_cidr
      }
    ]
  ])

  # Flatten: for each peer × each accepter_route_table_id → one route entry
  accepter_routes = flatten([
    for p in var.vpc_peers : [
      for rt_id in p.accepter_route_table_ids : {
        key              = "${p.name}-acc-${rt_id}"
        peer_name        = p.name
        route_table_id   = rt_id
        destination_cidr = p.requester_cidr
        accepter_region  = p.accepter_region
      }
    ]
  ])
}

resource "aws_route" "requester" {
  for_each = { for r in local.requester_routes : r.key => r }

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peer_name].id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

###############################################################################
# Routes — accepter side (uses accepter provider per region)
###############################################################################

resource "aws_route" "accepter" {
  for_each = { for r in local.accepter_routes : r.key => r }

  provider = aws.accepter

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = each.value.destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peer_name].id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}
