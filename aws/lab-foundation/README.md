# aws/lab-foundation

OpenTofu stack for the first AWS-resident primitives in the `lab` account:

- VPC (`172.16.0.0/16`)
- single public subnet
- internet gateway + public route table
- Route 53 private hosted zone for `glab.lol`
- Route 53 public hosted zone for delegated ACME DNS-01 validation
- customer-managed KMS key for SOPS

This stack intentionally stops at the shared foundation layer. It does **not**
yet create EC2 instances, Tailscale, security groups, SSM bootstrap material,
or Keycloak-specific infrastructure.

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the
  `lab` account

The expected local operator flow is to export both values via `direnv`.

## Usage

```sh
just check
just init
just plan
just apply
```

`just init` uses `GLAB_AWS_STATE_BUCKET` to finish the otherwise-partial S3
backend configuration. The backend bucket itself is part of the manual AWS
bootstrap and is intentionally not managed by this stack.

After apply, delegate the `acme.glab.lol` public zone from Cloudflare using
the `acme_zone_name_servers` output. ACME clients should publish DNS-01 TXT
records in this delegated Route 53 zone instead of receiving Cloudflare API
credentials.
