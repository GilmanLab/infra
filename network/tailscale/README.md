# Tailscale

This stack manages tailnet settings that are not part of the Tailscale ACL
policy file.

It currently:

- keeps MagicDNS enabled
- points the lab split DNS zones at the VyOS recursor
- manages the AWS subnet router federated identity used for workload identity
  federation from the `lab` AWS account

- `lab.gilman.io`
- `10.10.10.in-addr.arpa`
- `70.10.10.in-addr.arpa`

Credentials come from the private `secrets` repo at
`network/tailscale/terraform.sops.yaml`.

The OAuth client in that file must be permitted to manage both DNS settings and
trust credentials in the tailnet.
