# root-ca

Offline-by-policy root CA for the glab internal PKI. The signing key is
generated inside `AWS KMS` and never exported; the online intermediate
(`step-ca` on the `VP6630`) is signed against it only when an intermediate
is minted or rotated.

## Prerequisites

- `tofu` >= 1.10
- `aws-vault` with a `jmgilman-prod` profile
- `aws` CLI
- `just`
- `step` CLI with the `step-kms-plugin` binary on `PATH` (for cert minting)

## Key (Tofu)

```
just bootstrap-backend   # one-time: creates the shared state bucket
just init
just plan
just apply
```

Run `just` with no arguments for the full recipe list.

## Certificate

The committed `root_ca.crt` is the self-signed trust anchor issued by the KMS
key. `root_ca.fingerprint` contains the SHA-256 fingerprint used for client
bootstrap via `step ca bootstrap --fingerprint …`.

### Re-mint the root certificate

Only needed if the current certificate approaches expiry or its template
changes. Guard against accidental regeneration — a new cert invalidates every
existing bootstrap.

```
KEY_ID=$(aws-vault exec jmgilman-prod -- \
  aws kms describe-key --key-id alias/glab-pki-root-ca \
  --region us-west-2 --query KeyMetadata.KeyId --output text)

aws-vault exec jmgilman-prod -- step certificate create 'glab Root CA' \
  root_ca.crt \
  --profile root-ca --not-after 175200h \
  --kms 'awskms:region=us-west-2' \
  --key "awskms:key-id=${KEY_ID}" \
  --force

step certificate fingerprint root_ca.crt > root_ca.fingerprint
```

### Re-mint the intermediate certificate

The intermediate private key lives in `../../../network/vyos/ansible/files/`
companion to the committed `intermediate_ca.crt`. The intermediate is rotated
when it approaches expiry (5-year validity) or when the key is believed
compromised.

```
INTERMEDIATE_PW=$(openssl rand -base64 32)
PWFILE=$(mktemp) && printf '%s' "$INTERMEDIATE_PW" > "$PWFILE" && chmod 600 "$PWFILE"

aws-vault exec jmgilman-prod -- step certificate create 'glab Intermediate CA' \
  /tmp/intermediate_ca.crt /tmp/intermediate_ca.key \
  --profile intermediate-ca --not-after 43800h \
  --kty EC --crv P-384 \
  --ca root_ca.crt \
  --ca-kms 'awskms:region=us-west-2' \
  --ca-key "awskms:key-id=${KEY_ID}" \
  --password-file "$PWFILE"

cp /tmp/intermediate_ca.crt ../../../network/vyos/ansible/files/intermediate_ca.crt

# SOPS-update the router-shipped key + password (single edit):
export PW=$INTERMEDIATE_PW KEY=$(cat /tmp/intermediate_ca.key)
EDITOR="yq eval -i '.intermediate_key_password = strenv(PW) | .intermediate_key_pem = strenv(KEY)'" \
  sops ../../../../../secrets/network/vyos/pki/stepca.sops.yaml

rm -P -f /tmp/intermediate_ca.{crt,key} "$PWFILE"
```

Then redeploy step-ca via `infra/network/vyos/ansible/playbooks/deploy.yml`.

### Rotate the JWK provisioner password

If `jwk_client_password` is rotated, the wrapped `jwk_encrypted_key` must be
re-wrapped with the new password in the same SOPS edit, or step-ca will
refuse certificate issuance.

```
JWK_PW=$(openssl rand -base64 24)
TMPDIR=$(mktemp -d) && chmod 700 "$TMPDIR"

# Decrypt current JWE to raw, then re-encrypt with the new password.
# (Requires prompting for the current password.)
step crypto jwk create "$TMPDIR/pub.json" "$TMPDIR/priv.json" \
  --use sig --password-file <(printf '%s' "$JWK_PW")

COMPACT=$(jq -r '.protected + "." + .encrypted_key + "." + .iv + "." + .ciphertext + "." + .tag' \
  < "$TMPDIR/priv.json")

export JWK_PUB=$(cat "$TMPDIR/pub.json") JWK_ENC="$COMPACT" JWK_PW

EDITOR="yq eval -i '.jwk_public_jwk = strenv(JWK_PUB) | .jwk_encrypted_key = strenv(JWK_ENC) | .jwk_client_password = strenv(JWK_PW)'" \
  sops ../../../../../secrets/network/vyos/pki/stepca.sops.yaml

rm -rf "$TMPDIR"
```

Redeploy step-ca afterward to roll the new `ca.json`.

## Notes

- Key spec: `ECC_NIST_P384`, `SIGN_VERIFY`, 30-day deletion window.
- State: `s3://gilmanlab-tfstate/security/pki/root-ca.tfstate` (`us-west-2`),
  encrypted, versioned, native S3 locking.
- Key policy is the AWS default; signing rights are granted per-use via IAM
  (`jmgilman-prod`), not standing. Only the minting flows above consume the
  key — step-ca itself never talks to KMS.
- Root validity: 20 years. Intermediate validity: 5 years. `pathlen:1` on root
  caps the chain at exactly one intermediate.
