################################################################################
# FORGE — Network: 3-Tier VPC Baseline
# Public (ALB only) / Private App / Private Data
# Regulatory: NIST SC-7 | SOC2 CC6.6 | FFIEC IS.10
################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-vpc"
    FORGE_Control = "NET-001"
    NIST_Control  = "SC-7"
    SOC2_Control  = "CC6.6"
  })
}

# Block all default VPC resources — FORGE workloads only use purpose-built VPCs
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
  # No ingress or egress rules — deny all by default
  tags = { Name = "FORGE-default-sg-deny-all" }
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id
  # No rules — deny all
  tags = { Name = "FORGE-default-nacl-deny-all" }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  # No routes
  tags = { Name = "FORGE-default-rt-empty" }
}

# -----------------------------------------------------------------------------
# Internet Gateway (Public subnet tier only — restricted by SCP to network role)
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# -----------------------------------------------------------------------------
# Subnets — 3 tiers across n AZs
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false  # Never auto-assign public IPs

  tags = merge(var.tags, {
    Name            = "${var.name_prefix}-public-${local.azs[count.index]}"
    Tier            = "public"
    FORGE_Control   = "NET-002"
    "kubernetes.io/role/elb" = "1"  # Optional: EKS ALB annotation
  })
}

resource "aws_subnet" "private_app" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-private-app-${local.azs[count.index]}"
    Tier          = "private-app"
    FORGE_Control = "NET-003"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_data" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-private-data-${local.azs[count.index]}"
    Tier          = "private-data"
    FORGE_Control = "NET-004"
  })
}

# -----------------------------------------------------------------------------
# NAT Gateways (one per AZ for HA; app tier egress only)
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = var.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-${local.azs[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-private-app-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "private_app" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_data" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  # No default route — data tier has no internet access whatsoever

  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-private-data-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "private_data" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

# -----------------------------------------------------------------------------
# VPC Flow Logs — all traffic, to CloudWatch and S3
# -----------------------------------------------------------------------------

resource "aws_flow_log" "s3" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.log_archive_bucket_arn}/vpc-flow-logs/${aws_vpc.this.id}/"

  tags = merge(var.tags, {
    FORGE_Control = "NET-005"
    NIST_Control  = "AU-2 SC-7"
  })
}

# -----------------------------------------------------------------------------
# Security Groups (baseline deny-all; workloads add specific rules)
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "FORGE baseline: ALB inbound HTTPS only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "ALB to app tier"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [for s in aws_subnet.private_app : s.cidr_block]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg", FORGE_Control = "NET-006" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "FORGE baseline: App tier - inbound from ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Inbound from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS egress (AWS APIs, external)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "App to data tier"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.data.id]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-app-sg", FORGE_Control = "NET-007" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "data" {
  name        = "${var.name_prefix}-data-sg"
  description = "FORGE baseline: Data tier - inbound from app tier only, no egress"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-data-sg", FORGE_Control = "NET-008" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "data_from_app" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data.id
  source_security_group_id = aws_security_group.app.id
  description              = "Inbound from app tier only"
}
