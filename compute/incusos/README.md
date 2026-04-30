# IncusOS Bootstrap Inputs

This directory is the durable home for the lab's IncusOS/Tinkerbell bootstrap
inputs.

It now has a strict split:

- CUE is the only manifest source of truth.
- `kubectl` consumes `cue export` output directly.
- `labctl` builds the seeded IncusOS image from the shared schema input.
- the remaining imperative helper is `scripts/imagectl.py`, which stages the
  built image to VyOS.

The first supported host flow is `um760`. The `ms02-*` host data still exists
in CUE, but joiner export fails deliberately until that flow is implemented.

## Layout

- [`config.cue`](./config.cue) stores shared defaults, host data, host
  selection, and the Tinkerbell manifest inputs.
- [`image-build.um760.yaml`](./image-build.um760.yaml) is the `labctl`
  IncusOS image build input for the first supported host.
- [`manifests.cue`](./manifests.cue) defines the Tinkerbell `Hardware`,
  `Template`, and `Workflow` objects and the manifest stream export.
- [`scripts/imagectl.py`](./scripts/imagectl.py) stages the built image to
  VyOS. It does not render manifests or own kubectl orchestration.
- [`Justfile`](./Justfile) is the operator entrypoint.

## Secrets

`image-build` reads the durable client identity from the sibling `secrets/`
repository via `GLAB_SECRETS_DIR`.

The expected decrypted YAML shape at
`compute/incusos/bootstrap-client.sops.yaml` is:

```yaml
client_name: glab-bootstrap
client_crt_pem: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
client_key_pem: |
  -----BEGIN PRIVATE KEY-----
  ...
  -----END PRIVATE KEY-----
```

## Workflow

Validate the declarative package:

```sh
just vet
```

Export the selected host's manifest stream for inspection:

```sh
just export
```

Dry-run or apply the selected host's manifest stream directly:

```sh
just dry-run
just apply
just delete
```

Build the local first-node operation image with `labctl`:

```sh
GLAB_SECRETS_DIR=/path/to/secrets just image-build
```

Set `LABCTL=/path/to/labctl` when the binary is not already on `PATH`.

Stage the built image to the VyOS artifact directory served on LAB_PROV:

```sh
GLAB_SECRETS_DIR=/path/to/secrets just image-stage-vyos
```

The exported workflow expects the first-node image to be served from:

`http://10.10.20.1:18080/incusos-operation-first-node-x86_64.img.gz`

`infra/network/vyos` owns that static artifact-serving path and the released
`bootstrap-k0s` container that consumes the published GHCR image from
`platform`.
