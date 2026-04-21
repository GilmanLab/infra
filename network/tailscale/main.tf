locals {
  aws_subnet_router_scopes = toset([
    "auth_keys",
  ])

  aws_subnet_router_routes = toset([
    "172.16.0.0/16",
  ])

  lab_split_dns_domains = toset([
    "glab.lol",
    "lab.gilman.io",
    "10.10.10.in-addr.arpa",
    "70.10.10.in-addr.arpa",
  ])

  lab_dns_nameservers = [
    "10.10.10.1",
  ]
}

resource "tailscale_dns_preferences" "magic_dns" {
  magic_dns = true
}

resource "tailscale_dns_split_nameservers" "lab" {
  for_each = local.lab_split_dns_domains

  domain      = each.value
  nameservers = local.lab_dns_nameservers
}

resource "tailscale_federated_identity" "aws_subnet_router" {
  description = "glab AWS subnet router"
  issuer      = var.aws_subnet_router_issuer
  scopes      = local.aws_subnet_router_scopes
  subject     = var.aws_subnet_router_subject
  tags        = [var.aws_subnet_router_tag]
}

data "tailscale_device" "aws_subnet_router" {
  hostname = "glab-aws-subnet-router"
  wait_for = "120s"
}

resource "tailscale_device_subnet_routes" "aws_subnet_router" {
  device_id = data.tailscale_device.aws_subnet_router.node_id
  routes    = local.aws_subnet_router_routes
}
