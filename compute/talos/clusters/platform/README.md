# Platform Talos Cluster

This directory holds the source-controlled inputs for rendering the Talos
configuration used to bootstrap the platform cluster on the `UM760`.

## Layout

- `cluster.yaml` defines the cluster identity, pinned versions, secret lookup,
  output location, and the bootstrap artifact refs consumed from the `platform`
  repo.
- `schematic.yaml` is the durable boot-asset input used to resolve the Image
  Factory schematic ID.
- `patches/` holds stable patch files for cluster-wide, control-plane, and
  node-specific settings.
- `clusterctl.py` is a self-contained `uv` script for generating encrypted
  secrets, rendering Talos outputs, validating the rendered control-plane
  config, and generating a plain UEFI ISO with embedded config.
- `manifests/` holds cluster-local day-2 resources that are applied directly to
  the live platform cluster rather than baked into the Talos bootstrap
  artifact. The first such bundle is the Cilium LB IPAM + BGP config plus the
  Argo CD `LoadBalancer` service patch.
- `scripts/bootstrap.py` is a self-contained `uv` script that reads the
  rendered control-plane config, discovers the node IP, and runs
  `talosctl bootstrap` only when etcd is not already initialized.
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
7. `just kubeconfig`

Rendered outputs are disposable and live under `.state/rendered/`.
Generated ISO assets and metadata live under `.state/boot-assets/`.

`just bootstrap` runs `scripts/bootstrap.py`, which reads the control-plane IP
from `.state/rendered/controlplane.yaml` and uses
`.state/rendered/talosconfig` for Talos API authentication, so the workflow
does not hardcode any node address.

`just kubeconfig` reads the same rendered control-plane IP and Talos client
config, then runs `talosctl kubeconfig --force-context-name platform --force`
against that node so the admin kubeconfig is merged into the local default
kubectl config under the stable context name `platform`.

## Live Cilium BGP / LB Workflow

The platform cluster keeps the Cilium core bootstrap artifact in Talos machine
config, but the cluster-local BGP peering, LB IPAM pool, and Argo CD service
exposure are applied directly to the live cluster.

The expected sequence is:

1. apply the updated branch-local Cilium render to the cluster
2. `just cilium-bgp-apply`
3. `just argocd-server-lb-apply`
4. `just cilium-bgp-status`
5. `just argocd-server-lb-status`

This first cut is intentionally scoped to the current single-node `platform`
cluster:

- active BGP peer: `10.10.10.1` (`VP6630`)
- active Cilium node: `10.10.10.10`
- LB IPAM pool: `10.10.10.64/28`
- advertised service: `argocd/argocd-server`

## Bootstrap Artifact Contract

`cluster.yaml` carries the commit-pinned bootstrap artifact source under
`bootstrapArtifacts`.

- `repo.owner` / `repo.name` identify the public `platform` repo.
- each component `ref` must be the full commit SHA that corresponds to the
  released tag chosen for that component bootstrap artifact.
- each component `path` points at the tracked rendered manifest in that repo.

`clusterctl.py` converts those fields into raw GitHub URLs and synthesizes the
Talos bootstrap patch during render time. That patch:

- configures Talos to use the released Cilium manifest as the custom CNI
- disables kube-proxy for kube-proxy-free Cilium
- installs Argo CD and kro via `extraManifests`

The current pinned release refs are:

- `cilium-v1.1.0` -> `8468c1520f51e7f247f3c8cba5eb9fab98e5ad49`
- `argocd-v1.0.1` -> `f12b0e58e8dd7187d7302089c1b08a8de1baa28c`
- `kro-v1.0.0` -> `9e9647394d8047c887fd3ea11be6302ca003165a`

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
