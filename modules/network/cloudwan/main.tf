################################################################################
# FORGE — Network: AWS Cloud WAN
#
# Cloud WAN is the default enterprise network fabric for FORGE.
# It provides a globally managed, policy-driven core network across all
# AWS regions and accounts in the Organization.
#
# Architecture:
#   Global Network
#   └── Core Network (policy-driven)
#       ├── Segment: workload        (prod/non-prod VPC attachments)
#       ├── Segment: shared-services (DNS, PKI, monitoring)
#       └── Segment: inspection      (ingress/egress through centralized firewall)
#
# VPC attachments are shared cross-account via AWS RAM.
# Segment assignment is tag-driven: tag VPCs with ForgeSegment=<segment-name>.
# Routing between segments is controlled by the core network policy document.
################################################################################

###############################################################################
# Global Network
###############################################################################

resource "aws_networkmanager_global_network" "this" {
  description = "FORGE global network - managed WAN backbone"
  tags        = merge(var.tags, { Name = "${var.name_prefix}-global-network" })
}

###############################################################################
# Core Network
###############################################################################

resource "aws_networkmanager_core_network" "this" {
  global_network_id = aws_networkmanager_global_network.this.id
  description       = "FORGE core network - policy-driven segmented routing"
  tags              = merge(var.tags, { Name = "${var.name_prefix}-core-network" })

}

resource "aws_networkmanager_core_network_policy_attachment" "this" {
  core_network_id = aws_networkmanager_core_network.this.id
  policy_document = jsonencode(local.core_network_policy)
}

###############################################################################
# Core Network Policy
# Segments, edge locations, tag-based attachment rules, and inter-segment routing.
###############################################################################

locals {
  core_network_policy = {
    version = "2021.12"

    "core-network-configuration" = {
      "asn-ranges"       = var.asn_ranges
      "vpn-ecmp-support" = false
      "edge-locations"   = [for r in var.edge_locations : { location = r }]
    }

    segments = [
      {
        name                            = "workload"
        "require-attachment-acceptance" = false
        "isolate-attachments"           = false
      }
    ]

    "attachment-policies" = [
      {
        "rule-number" = 100
        conditions    = [{ type = "any" }]
        action        = { "association-method" = "constant", segment = "workload" }
      }
    ]
  }
}

###############################################################################
# VPC Attachments
# Each entry in var.vpc_attachments creates one attachment.
# Set ForgeSegment tag to control which policy segment the VPC joins.
###############################################################################

resource "aws_networkmanager_vpc_attachment" "this" {
  for_each = { for a in var.vpc_attachments : a.name => a }

  core_network_id = aws_networkmanager_core_network.this.id
  vpc_arn         = each.value.vpc_arn
  subnet_arns     = each.value.subnet_arns

  options {
    appliance_mode_support = lookup(each.value, "appliance_mode", false)
    ipv6_support           = lookup(each.value, "ipv6_support", false)
  }

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-attachment-${each.key}"
    ForgeSegment = lookup(each.value, "segment", "workload")
  })

  # Policy must be live (AVAILABLE) before VPC attachments can be created
  depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}

###############################################################################
# AWS RAM — Share the Core Network with the entire AWS Organization
# Allows spoke accounts to create VPC attachments without a separate share per account.
###############################################################################

resource "aws_ram_resource_share" "core_network" {
  count                     = var.share_with_organization ? 1 : 0
  name                      = "${var.name_prefix}-core-network-share"
  allow_external_principals = false
  tags                      = merge(var.tags, { Name = "${var.name_prefix}-core-network-share" })
}

resource "aws_ram_resource_association" "core_network" {
  count              = var.share_with_organization ? 1 : 0
  resource_share_arn = aws_ram_resource_share.core_network[0].arn
  resource_arn       = aws_networkmanager_core_network.this.arn
}

# RAM org sharing propagation takes 30-60s after aws ram enable-sharing-with-aws-organization
resource "time_sleep" "ram_propagation" {
  count           = var.share_with_organization ? 1 : 0
  depends_on      = [aws_ram_resource_share.core_network]
  create_duration = "60s"
}

resource "aws_ram_principal_association" "org" {
  count              = var.share_with_organization ? 1 : 0
  resource_share_arn = aws_ram_resource_share.core_network[0].arn
  principal          = var.organization_arn
  depends_on         = [time_sleep.ram_propagation]
}

###############################################################################
# CloudWatch — Attachment health alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "attachment_state" {
  for_each = { for a in var.vpc_attachments : a.name => a }

  alarm_name          = "forge-cloudwan-${each.key}-pending"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "AttachmentPendingTransitionCount"
  namespace           = "AWS/NetworkManager"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "FORGE Cloud WAN attachment ${each.key} is stuck pending - check core network policy"
  alarm_actions       = var.alarm_topic_arns
  ok_actions          = var.alarm_topic_arns

  dimensions = {
    CoreNetworkId = aws_networkmanager_core_network.this.id
  }

  tags = merge(var.tags, {
    FORGE_Control = "FORGE-NET-004"
    NIST_Control  = "SC-7"
  })
}
