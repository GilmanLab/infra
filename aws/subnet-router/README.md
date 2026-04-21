# aws/subnet-router

OpenTofu stack for the AWS-side subnet router in the `lab` account.

This stack creates:

- the EC2 instance profile and IAM role for Tailscale workload identity federation
- the EC2 subnet router instance
- the public Elastic IP
- the security group and VPC route entries needed to reach the lab CIDRs
- the SSM-driven host configuration that installs Docker and deploys `dns-mirror`

This stack assumes the shared network primitives already exist in
`aws/lab-foundation`.

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the
  `lab` account
- the Tailscale trust credential already created in `network/tailscale`

The `tailscale_client_id` and `tailscale_audience` values are not secrets. They
come from the `network/tailscale` outputs and are committed in this root
module's `terraform.tfvars`.

The `dns_mirror_image` value is intentionally pinned to an immutable semver tag
from the `platform` repo. The deployment wiring can be applied only after that
image exists in GHCR.

## Usage

```sh
just check
just init
just plan
just apply
```
