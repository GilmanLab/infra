locals {
  lab_split_dns_domains = toset([
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
