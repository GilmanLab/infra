# aws/keycloak

OpenTofu stack for the first AWS-hosted Keycloak instance in the `lab`
account.

This stack creates:

- a dedicated `t4g.small` Amazon Linux 2023 EC2 instance
- an IAM role and instance profile for SSM management
- a security group that exposes HTTPS only to lab CIDRs
- a private Route 53 `A` record for `id.glab.lol`
- an SSM-driven Docker Compose deployment for Postgres, Keycloak, and Traefik

This stack intentionally stops at starting Keycloak. It does **not** configure
realms, GitHub OIDC, clients, backups, Synology sync, Kubernetes OIDC, Argo CD,
Grafana, IAM Identity Center federation, or `keycloak-config-cli`.

The first bring-up uses a temporary self-signed certificate on Traefik. Public
ACME DNS-01 is deferred because the existing `glab.lol` Route 53 zone is
private and public CAs must validate DNS challenges through public DNS.

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the
  `lab` account
- the `aws/lab-foundation` and `aws/subnet-router` stacks already applied

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

After apply, use SSM to inspect the host:

```sh
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets Key=instanceids,Values="$(tofu output -raw instance_id)" \
  --parameters commands='["docker compose --env-file /opt/keycloak/stack.env -f /opt/keycloak/compose.yml ps","curl -fsS http://127.0.0.1:9000/health/ready"]'
```
