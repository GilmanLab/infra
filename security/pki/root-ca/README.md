# root-ca

Offline-by-policy root CA KMS key for the glab internal PKI.

The signing key is generated inside AWS KMS in the current `lab` account and
never exported. This stack manages only the KMS key and alias. Root
certificate minting is an explicit operator action after the key exists.

## Prerequisites

- `tofu` >= 1.10
- `aws` CLI credentials for the `lab` account
- `just`
- `step` CLI with the `step-kms-plugin` binary on `PATH` for certificate
  minting

The expected local operator flow is to export these from the workspace
`.envrc`:

```sh
export AWS_PROFILE=lab-admin
export GLAB_AWS_STATE_BUCKET=glab-lab-tfstate-186067932323
```

## Key

```sh
just check
just init
just plan
just apply
```

`just init` uses `GLAB_AWS_STATE_BUCKET` to configure the otherwise-partial S3
backend. The backend bucket is part of the manual AWS bootstrap and is not
managed by this stack.

Run `just` with no arguments for the full recipe list.

## Certificate

The committed `root_ca.crt` is the self-signed trust anchor issued by the KMS
key. `root_ca.fingerprint` contains the SHA-256 fingerprint used by clients
that need an out-of-band trust bootstrap value.

The root uses `pathlen:2` so the future hierarchy remains open:

```text
Root CA pathlen:2
  -> cluster Vault intermediate pathlen:1
    -> SPIRE intermediate pathlen:0
      -> workload SVID leaves
```

Use the checked-in `templates/root-ca.tpl` template when re-minting this
certificate. The built-in `step certificate create --profile root-ca` profile
produces the older `pathlen:1` shape.

```sh
KEY_ID=$(aws kms describe-key \
  --key-id alias/glab-pki-root-ca \
  --region us-west-2 \
  --query KeyMetadata.KeyId \
  --output text)

step certificate create 'glab Root CA' root_ca.crt \
  --template templates/root-ca.tpl \
  --not-after 175200h \
  --kms 'awskms:region=us-west-2' \
  --key "awskms:key-id=${KEY_ID}" \
  --force

step certificate fingerprint root_ca.crt > root_ca.fingerprint
```

## Notes

- Target account: `186067932323` (`lab`)
- Region: `us-west-2`
- Alias: `alias/glab-pki-root-ca`
- Key spec: `ECC_NIST_P384`, `SIGN_VERIFY`, 30-day deletion window
- Root validity: 20 years
- State: `s3://glab-lab-tfstate-186067932323/security/pki/root-ca.tfstate`,
  encrypted with native S3 locking
- Key policy is the AWS default; signing rights should be granted per use, not
  held by always-on lab workloads
