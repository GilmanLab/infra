# root-ca

Offline-by-policy root CA for the glab internal PKI. The signing key is
generated inside `AWS KMS` and never exported; the online intermediate
(`step-ca` on the `VP6630`) signs against it only to create or rotate
intermediates.

## Prerequisites

- `tofu` >= 1.10
- `aws-vault` with a `jmgilman-prod` profile
- `aws` CLI
- `just`

## Usage

```
just bootstrap-backend   # one-time: creates the shared state bucket
just init
just plan
just apply
```

Run `just` with no arguments for the full recipe list.

## Notes

- Key spec: `ECC_NIST_P384`, `SIGN_VERIFY`, 30-day deletion window.
- State: `s3://gilmanlab-tfstate/security/pki/root-ca.tfstate` (`us-west-2`),
  encrypted, versioned, native S3 locking.
- Key policy is the AWS default; signing rights are granted per-use via IAM,
  not standing.
