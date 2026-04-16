# Tailscale DNS

This stack manages tailnet DNS settings that are not part of the Tailscale ACL
policy file.

It currently keeps MagicDNS enabled and points the lab split DNS zones at the
VyOS recursor:

- `lab.gilman.io`
- `10.10.10.in-addr.arpa`
- `70.10.10.in-addr.arpa`

Credentials come from the private `secrets` repo at
`network/tailscale/terraform.sops.yaml`.
