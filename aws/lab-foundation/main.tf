data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "glab-lab-vpc"
  })
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "glab-lab-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.selected_availability_zone
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "glab-lab-public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "glab-lab-public"
  })
}

resource "aws_route" "public_ipv4_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route53_zone" "private" {
  name    = var.private_zone_name
  comment = "Private hosted zone of record for the lab."

  tags = merge(local.common_tags, {
    Name = var.private_zone_name
  })

  vpc {
    vpc_id = aws_vpc.lab.id
  }
}

resource "aws_route53_zone" "acme" {
  name    = var.acme_zone_name
  comment = "Public ACME DNS-01 validation zone for lab bootstrap services."

  tags = merge(local.common_tags, {
    Name = var.acme_zone_name
  })
}

resource "aws_kms_key" "sops" {
  description             = "SOPS recipient key for lab bootstrap and automation material."
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "glab-sops"
  })
}

resource "aws_kms_alias" "sops" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.sops.key_id
}
