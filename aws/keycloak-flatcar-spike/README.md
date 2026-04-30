# AWS Keycloak Flatcar Spike

Temporary OpenTofu root for proving the Flatcar bootstrap path before moving the live Keycloak host off AL2023.

This stack intentionally creates only a sidecar EC2 instance:

- Flatcar stable arm64 in the existing lab public subnet
- outbound-only security group
- temporary IAM role and instance profile
- encrypted 16 GiB gp3 root volume
- no DNS records
- no persistent application data volume

On boot, Ignition enables `glab-keycloak-bootstrap.service`. The unit runs the pinned `labctl` container with host networking and writes the decrypted `stack_env` field from `services/keycloak/bootstrap.sops.yaml` to `/run/glab/keycloak/stack.env`.

## Validation

```sh
just check
AWS_PROFILE=lab-admin AWS_REGION=us-west-2 just init
AWS_PROFILE=lab-admin AWS_REGION=us-west-2 just plan
```

After apply, inspect only non-secret metadata through SSM:

```sh
systemctl is-active glab-keycloak-bootstrap.service
stat -c '%a %s %n' /run/glab/keycloak/stack.env
cut -d= -f1 /run/glab/keycloak/stack.env | sort
```

Do not print the full `/run/glab/keycloak/stack.env` contents.
