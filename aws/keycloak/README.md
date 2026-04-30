# aws/keycloak

OpenTofu stack for the AWS-hosted Keycloak instance in the `lab` account.

This stack creates:

- a dedicated `t4g.small` Flatcar Container Linux EC2 instance
- a dedicated encrypted gp3 data volume mounted at `/var/lib/keycloak`
- an IAM role and instance profile for SSM management
- a security group that exposes HTTPS only to lab CIDRs
- a private Route 53 `A` record for `id.glab.lol`
- scoped Route 53 permissions for ACME DNS-01 validation in `acme.glab.lol`
- a GitHub token broker Lambda, sourced from `meigma/github-token-broker`, for short-lived `GilmanLab/secrets` access
- Keycloak instance-role permission to invoke the token broker
- Keycloak instance-role permission to decrypt only SOPS secrets with `Repo=GilmanLab/secrets` and `Scope=keycloak`
- Ignition-managed systemd units for Postgres, Keycloak, Traefik, bootstrap secret fetches, and first-boot realm configuration

This stack configures only the initial `lab` realm and one local admin account with password plus WebAuthn/YubiKey enrollment. It does **not** configure GitHub OIDC, service clients, backups, Synology sync, Kubernetes OIDC, Argo CD, Grafana, or IAM Identity Center federation.

Traefik obtains the `id.glab.lol` certificate from Let's Encrypt through DNS-01. Cloudflare delegates `_acme-challenge.id.glab.lol` to the public Route 53 `acme.glab.lol` zone, and the Keycloak instance role may mutate only the delegated TXT record for this hostname.

## Bootstrap model

Flatcar receives raw Ignition JSON through EC2 user data. Ignition writes non-secret runtime config and helper scripts under `/etc/glab/keycloak`, then enables the systemd units.

`glab-keycloak-bootstrap.service` runs the pinned `labctl` container:

```sh
secrets get services/keycloak/bootstrap.sops.yaml \
  --source github \
  --field /stack_env \
  --output /run/glab/keycloak/stack.env \
  --aws-region us-west-2 \
  --broker-function glab-github-token-broker
```

Plaintext bootstrap material is written only under `/run/glab/keycloak`. The persistent data volume stores Postgres state in `/var/lib/keycloak/postgres` and ACME state in `/var/lib/keycloak/acme`; the Postgres directory is owned by the container's Postgres UID.

`glab-keycloak-config.service` runs once after Keycloak is healthy. It fetches
`services/keycloak/admin.sops.yaml` through the same broker-backed `labctl`
path, writes `/run/glab/keycloak/admin.env`, then runs pinned
`keycloak-config-cli` to create the `lab` realm, local admin user, and
touch-only WebAuthn policy. The service writes
`/var/lib/keycloak/config/lab-realm-imported` after a successful import so it
does not run again on reboot.

After enrolling and validating the admin YubiKey in the browser, disable the
temporary master bootstrap admin manually:

```sh
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets Key=instanceids,Values="$(tofu output -raw instance_id)" \
  --parameters commands='["systemctl start glab-keycloak-disable-bootstrap-admin.service"]'
```

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the `lab` account
- the `aws/lab-foundation` and `aws/subnet-router` stacks already applied
- the GitHub App SSM parameters created outside Terraform:
  `/glab/bootstrap/github-app/client-id`,
  `/glab/bootstrap/github-app/installation-id`, and
  `/glab/bootstrap/github-app/private-key-pem`
- `gh` and `sha256sum` on the apply host so the broker module can download and verify the pinned release asset
- Cloudflare delegates `acme.glab.lol` to the `aws/lab-foundation` `acme_zone_name_servers` output and sets `_acme-challenge.id.glab.lol` as a CNAME to `_acme-challenge.id.acme.glab.lol`
- `secrets/services/keycloak/bootstrap.sops.yaml` exists in `GilmanLab/secrets` with SOPS KMS context `Repo=GilmanLab/secrets` and `Scope=keycloak`
- `secrets/services/keycloak/admin.sops.yaml` exists in `GilmanLab/secrets` with SOPS KMS context `Repo=GilmanLab/secrets` and `Scope=keycloak`

The expected local operator flow is to export both AWS values via `direnv`.

## Legacy token broker cleanup

The old `aws/github-token-broker` stack used the same default Lambda name, `glab-github-token-broker`, and was originally published from `GilmanLab/platform`. Do not apply both stacks at the same time.

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

Then apply `aws/keycloak`. This removes the legacy Lambda resources while leaving the GitHub Actions OIDC provider alone; only run a full destroy after confirming that provider has no shared use.

## Usage

```sh
just check
just init
just plan
just apply
```

`just init` uses `GLAB_AWS_STATE_BUCKET` to finish the otherwise-partial S3 backend configuration. The backend bucket itself is part of the manual AWS bootstrap and is intentionally not managed by this stack.

After apply, use SSM to inspect the host without printing secret values:

```sh
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets Key=instanceids,Values="$(tofu output -raw instance_id)" \
  --parameters commands='[
    "systemctl is-active glab-keycloak-bootstrap.service glab-keycloak-postgres.service glab-keycloak.service glab-keycloak-traefik.service",
    "systemctl is-active glab-keycloak-config.service || systemctl status --no-pager glab-keycloak-config.service",
    "findmnt /var/lib/keycloak",
    "stat -c %a\\ %s\\ %n /run/glab/keycloak/stack.env",
    "stat -c %a\\ %s\\ %n /run/glab/keycloak/admin.env",
    "cut -d= -f1 /run/glab/keycloak/stack.env | sort",
    "cut -d= -f1 /run/glab/keycloak/admin.env | sort",
    "curl -fsS http://127.0.0.1:9000/health/ready"
  ]'
```
