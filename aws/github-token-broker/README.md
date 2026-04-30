# aws/github-token-broker

> Deprecated: the GitHub token broker is now owned by `aws/keycloak` through
> the reusable `meigma/github-token-broker` Terraform module. Keep this stack
> only long enough to destroy the legacy `glab-github-token-broker` resources
> in AWS before applying `aws/keycloak`. The legacy state may also own the lab
> GitHub Actions OIDC provider; do not run a full destroy unless you have
> confirmed that provider is not shared.

OpenTofu stack for the GitHub token broker Lambda in the `lab` account.

This stack creates:

- a Go custom-runtime Lambda using `provided.al2023` and `arm64`
- a Lambda execution role scoped to the GitHub App bootstrap SSM parameters
- a CloudWatch log group with explicit retention
- a GitHub Actions OIDC provider, unless an existing provider ARN is supplied
- a tag-scoped publisher role for `GilmanLab/platform` release workflows
- an invoke policy that future bootstrap principals can attach

Terraform owns the Lambda infrastructure. The `platform` release workflow owns
function code updates after the initial placeholder package creates the
function.

## Prerequisites

- OpenTofu `>= 1.10`
- `just`
- `AWS_PROFILE` set to the `lab` account admin profile
- `GLAB_AWS_STATE_BUCKET` set to the pre-created S3 backend bucket in the
  `lab` account
- the GitHub App SSM parameters created in session 027:
  `/glab/bootstrap/github-app/client-id`,
  `/glab/bootstrap/github-app/installation-id`, and
  `/glab/bootstrap/github-app/private-key-pem`

If the lab account already has a GitHub Actions OIDC provider, set
`github_oidc_provider_arn` and import/reuse it rather than creating a duplicate.

## Usage

```sh
just check
just init
just plan
just apply
```

After the first apply, release `platform/services/github-token-broker` so the
`github-token-broker-v*` tag workflow publishes the real Lambda package.
