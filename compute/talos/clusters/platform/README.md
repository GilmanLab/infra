# Platform Talos Cluster

This directory holds the source-controlled inputs for rendering the Talos
configuration used to bootstrap the platform cluster on the `UM760`.

## Layout

- `cluster.yaml` defines the cluster identity, pinned versions, secret lookup,
  and output location.
- `schematic.yaml` is the durable boot-asset input used to resolve the Image
  Factory schematic ID.
- `patches/` holds stable patch files for cluster-wide, control-plane, and
  node-specific settings.
- `clusterctl.py` is a self-contained `uv` script for generating encrypted
  secrets, rendering Talos outputs, validating the rendered control-plane
  config, and generating a plain UEFI ISO with embedded config.
- `Justfile` exposes the operator entrypoints.

## Prerequisites

- `uv`
- `talosctl`
- `sops`
- `just`
- `yq`
- `zstd`
- `docker` or `podman`
- `GLAB_SECRETS_DIR` pointing at the sibling `secrets/` repository root

## Workflow

1. `just secrets-generate`
2. `just render`
3. `just validate`
4. `just iso-generate`
5. Boot the ISO on the target machine
6. `just bootstrap`

Rendered outputs are disposable and live under `.state/rendered/`.
Generated ISO assets and metadata live under `.state/boot-assets/`.

`just bootstrap` reads the control-plane IP from `.state/rendered/controlplane.yaml`
and uses `.state/rendered/talosconfig` for Talos API authentication, so the
recipe does not hardcode any node address.

## Boot Asset Flow

- `schematic.yaml` is uploaded to Image Factory to resolve a schematic ID.
- The matching installer image is derived from that schematic ID and the pinned
  Talos version.
- A temporary installer-aligned control-plane config is generated locally.
- The pinned `imager` container is run via `docker` or `podman` to produce the
  plain UEFI ISO with the config embedded.
- The current `imager` flow emits a compressed `.iso.zst` artifact internally,
  so the helper normalizes it back to the final `.iso` name in
  `.state/boot-assets/`.
- The container runtime invocation uses privileged mode for this path because
  the embedded-config extension build fails without it in the current local
  runtime environment.
