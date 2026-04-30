# aws/keycloak

OpenTofu stack for the first AWS-hosted Keycloak instance in the `lab`
account.

This stack creates:

- a dedicated `t4g.small` Amazon Linux 2023 EC2 instance
- an IAM role and instance profile for SSM management
- a security group that exposes HTTPS only to lab CIDRs
- a private Route 53 `A` record for `id.glab.lol`
- scoped Route 53 permissions for ACME DNS-01 validation in `acme.glab.lol`
- a GitHub token broker Lambda, sourced from
  `meigma/github-token-broker`, for short-lived `GilmanLab/secrets` access
- Keycloak instance-role permission to invoke the token broker
- an SSM-driven Docker Compose deployment for Postgres, Keycloak, and Traefik

This stack intentionally stops at starting Keycloak. It does **not** configure
realms, GitHub OIDC, clients, backups, Synology sync, Kubernetes OIDC, Argo CD,
Grafana, IAM Identity Center federation, or `keycloak-config-cli`.

Traefik obtains the `id.glab.lol` certificate from Let's Encrypt through
DNS-01. Cloudflare delegates `_acme-challenge.id.glab.lol` to the public
Route 53 `acme.glab.lol` zone, and the Keycloak instance role may mutate only
the delegated TXT record for this hostname.

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the
  `lab` account
- the `aws/lab-foundation` and `aws/subnet-router` stacks already applied
- the GitHub App SSM parameters created outside Terraform:
  `/glab/bootstrap/github-app/client-id`,
  `/glab/bootstrap/github-app/installation-id`, and
  `/glab/bootstrap/github-app/private-key-pem`
- `gh` and `sha256sum` on the apply host so the broker module can download and
  verify the pinned release asset
- Cloudflare delegates `acme.glab.lol` to the `aws/lab-foundation`
  `acme_zone_name_servers` output and sets
  `_acme-challenge.id.glab.lol` as a CNAME to
  `_acme-challenge.id.acme.glab.lol`

The expected local operator flow is to export both values via `direnv`.

## Legacy token broker cleanup

The old `aws/github-token-broker` stack used the same default Lambda name,
`glab-github-token-broker`, and was originally published from
`GilmanLab/platform`. Do not apply both stacks at the same time.

If the old Lambda is still active, retire it before applying this stack:

```sh
cd ../github-token-broker
just init
tofu plan -destroy \
  -target=aws_lambda_function.broker \
  -target=aws_cloudwatch_log_group.broker \
  -target=aws_iam_policy.invoke \
  -target=aws_iam_role.execution \
  -target=aws_iam_role.publisher \
  -target=aws_iam_role_policy.execution_logs \
  -target=aws_iam_role_policy.execution_ssm \
  -target=aws_iam_role_policy.publisher \
  -out=destroy-broker-only.tfplan
tofu apply destroy-broker-only.tfplan
```

Then apply `aws/keycloak`. This removes the legacy Lambda resources while
leaving the GitHub Actions OIDC provider alone; only run a full destroy after
confirming that provider has no shared use.

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
