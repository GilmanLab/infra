#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyYAML>=6.0,<7",
# ]
# ///
"""Local helper for the platform Talos cluster scaffold."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parent
CLUSTER_FILE = ROOT / "cluster.yaml"
PATCHES_DIR = ROOT / "patches"
SOPS_CONFIG = ".sops.yaml"
REQUIRED_TOOLS = ("talosctl", "sops", "yq")
IMAGE_FACTORY_URL = "https://factory.talos.dev/schematics"


class ClusterError(RuntimeError):
    """Raised when cluster inputs are invalid or unavailable."""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("generate-secrets", help="Generate and encrypt a Talos secrets bundle")
    subparsers.add_parser("render", help="Render Talos control-plane outputs locally")
    subparsers.add_parser("validate", help="Validate the rendered control-plane config")
    subparsers.add_parser("generate-iso", help="Generate a plain UEFI ISO with embedded config")
    args = parser.parse_args()

    try:
        ensure_tools()
        if args.command == "generate-secrets":
            generate_secrets()
        elif args.command == "render":
            render()
        elif args.command == "validate":
            validate()
        elif args.command == "generate-iso":
            generate_iso()
        else:
            raise ClusterError(f"unsupported command: {args.command}")
    except ClusterError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


def ensure_tools() -> None:
    missing = [tool for tool in REQUIRED_TOOLS if shutil.which(tool) is None]
    if missing:
        raise ClusterError(f"missing required tool(s): {', '.join(missing)}")


def run(cmd: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            cwd=str(cwd) if cwd is not None else None,
            check=True,
            text=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip() or "command failed"
        raise ClusterError(f"{' '.join(cmd)}: {message}") from exc


def load_config() -> dict:
    result = run(["yq", "-o=json", ".", str(CLUSTER_FILE)])
    data = json.loads(result.stdout)

    required = [
        "name",
        "endpoint",
        "talosVersion",
        "kubernetesVersion",
        "dnsDomain",
        "secretsFile",
        "outputDir",
    ]
    missing = [field for field in required if not data.get(field)]
    if missing:
        raise ClusterError(f"cluster.yaml is missing required field(s): {', '.join(missing)}")

    control_plane = data.get("nodes", {}).get("controlPlane", [])
    if len(control_plane) != 1:
        raise ClusterError("cluster.yaml must define exactly one controlPlane node for this iteration")
    if not control_plane[0].get("name"):
        raise ClusterError("controlPlane node entry must include a name")

    return data


def load_boot_assets(config: dict) -> dict:
    boot_assets = config.get("bootAssets")
    if not isinstance(boot_assets, dict):
        raise ClusterError("cluster.yaml is missing required bootAssets section")

    required = ["arch", "outputDir", "schematicFile"]
    missing = [field for field in required if not boot_assets.get(field)]
    if missing:
        raise ClusterError(f"bootAssets is missing required field(s): {', '.join(missing)}")

    return boot_assets


def load_bootstrap_artifacts(config: dict) -> dict:
    bootstrap = config.get("bootstrapArtifacts")
    if not isinstance(bootstrap, dict):
        raise ClusterError("cluster.yaml is missing required bootstrapArtifacts section")

    repo = bootstrap.get("repo")
    if not isinstance(repo, dict):
        raise ClusterError("bootstrapArtifacts is missing required repo section")

    repo_required = ["owner", "name"]
    repo_missing = [field for field in repo_required if not repo.get(field)]
    if repo_missing:
        raise ClusterError(f"bootstrapArtifacts.repo is missing required field(s): {', '.join(repo_missing)}")

    required = ["cilium", "argocd", "kro"]
    missing = [field for field in required if not bootstrap.get(field)]
    if missing:
        raise ClusterError(f"bootstrapArtifacts is missing required field(s): {', '.join(missing)}")

    for component in ("cilium", "argocd", "kro"):
        value = bootstrap.get(component)
        if not isinstance(value, dict):
            raise ClusterError(f"bootstrapArtifacts.{component} must be a mapping")
        component_missing = [field for field in ("ref", "path") if not value.get(field)]
        if component_missing:
            raise ClusterError(
                f"bootstrapArtifacts.{component} is missing required field(s): {', '.join(component_missing)}"
            )

    return bootstrap


def get_secrets_root() -> Path:
    raw = os.environ.get("GLAB_SECRETS_DIR")
    if not raw:
        raise ClusterError("GLAB_SECRETS_DIR is not set")

    path = Path(raw).expanduser().resolve()
    if not path.is_dir():
        raise ClusterError(f"GLAB_SECRETS_DIR does not exist: {path}")
    if not (path / SOPS_CONFIG).is_file():
        raise ClusterError(f"GLAB_SECRETS_DIR is missing {SOPS_CONFIG}: {path}")

    return path


def secrets_path(config: dict, secrets_root: Path) -> Path:
    return secrets_root / config["secretsFile"]


def output_dir(config: dict) -> Path:
    return ROOT / config["outputDir"]


def boot_assets_dir(boot_assets: dict) -> Path:
    return ROOT / boot_assets["outputDir"]


def schematic_path(boot_assets: dict) -> Path:
    return ROOT / boot_assets["schematicFile"]


def node_patch_path(node_name: str) -> Path:
    return PATCHES_DIR / "nodes" / f"{node_name}.yaml"


def raw_github_url(owner: str, repo: str, ref: str, path: str) -> str:
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}"


def bootstrap_patch(config: dict) -> dict:
    bootstrap = load_bootstrap_artifacts(config)
    repo = bootstrap["repo"]
    owner = repo["owner"]
    name = repo["name"]
    cilium_url = raw_github_url(owner, name, bootstrap["cilium"]["ref"], bootstrap["cilium"]["path"])
    argocd_url = raw_github_url(owner, name, bootstrap["argocd"]["ref"], bootstrap["argocd"]["path"])
    kro_url = raw_github_url(owner, name, bootstrap["kro"]["ref"], bootstrap["kro"]["path"])

    return {
        "cluster": {
            "network": {
                "cni": {
                    "name": "custom",
                    "urls": [cilium_url],
                }
            },
            "proxy": {
                "disabled": True,
            },
            "extraManifests": [
                argocd_url,
                kro_url,
            ],
        }
    }


def render_outputs(
    config: dict,
    target_dir: Path,
    *,
    output_types: tuple[str, ...],
    install_image: str | None = None,
) -> None:
    secrets_root = get_secrets_root()
    encrypted = secrets_path(config, secrets_root)
    node_name = config["nodes"]["controlPlane"][0]["name"]
    node_patch = node_patch_path(node_name)

    if not encrypted.is_file():
        raise ClusterError(f"encrypted secrets bundle does not exist: {encrypted}")
    if not node_patch.is_file():
        raise ClusterError(f"node patch file does not exist: {node_patch}")

    output_target = target_dir
    if len(output_types) == 1:
        shutil.rmtree(target_dir, ignore_errors=True)
        target_dir.mkdir(parents=True, exist_ok=True)
        output_name = "talosconfig" if output_types[0] == "talosconfig" else f"{output_types[0]}.yaml"
        output_target = target_dir / output_name
    else:
        shutil.rmtree(target_dir, ignore_errors=True)
        target_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="platform-talos-render-") as tmpdir:
        decrypted = Path(tmpdir) / "cluster-secrets.yaml"
        run(
            [
                "sops",
                "--decrypt",
                "--output",
                str(decrypted),
                str(encrypted),
            ]
        )
        bootstrap_patch_file = Path(tmpdir) / "bootstrap-manifests.yaml"
        try:
            bootstrap_patch_file.write_text(
                yaml.safe_dump(bootstrap_patch(config), sort_keys=False),
                encoding="utf-8",
            )
        except OSError as exc:
            raise ClusterError(f"failed to write bootstrap patch file: {exc}") from exc
        cmd = [
            "talosctl",
            "gen",
            "config",
            config["name"],
            config["endpoint"],
            "--with-secrets",
            str(decrypted),
            "--talos-version",
            config["talosVersion"],
            "--kubernetes-version",
            config["kubernetesVersion"],
            "--dns-domain",
            config["dnsDomain"],
            "--output",
            str(output_target),
        ]
        for output_type in output_types:
            cmd.extend(["--output-types", output_type])
        if install_image is not None:
            cmd.extend(["--install-image", install_image])
        cmd.extend(
            [
                "--config-patch",
                f"@{bootstrap_patch_file}",
                "--config-patch",
                f"@{PATCHES_DIR / 'common.yaml'}",
                "--config-patch-control-plane",
                f"@{PATCHES_DIR / 'controlplane.yaml'}",
                "--config-patch-control-plane",
                f"@{node_patch}",
            ]
        )
        run(cmd)


def generate_secrets() -> None:
    config = load_config()
    secrets_root = get_secrets_root()
    target = secrets_path(config, secrets_root)

    if target.exists():
        raise ClusterError(f"encrypted secrets bundle already exists: {target}")

    target.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="platform-talos-secrets-") as tmpdir:
        plaintext = Path(tmpdir) / "cluster-secrets.yaml"
        run(["talosctl", "gen", "secrets", "--output-file", str(plaintext)])
        run(
            [
                "sops",
                "--encrypt",
                "--config",
                str(secrets_root / SOPS_CONFIG),
                "--filename-override",
                config["secretsFile"],
                "--input-type",
                "yaml",
                "--output-type",
                "yaml",
                "--output",
                str(target),
                str(plaintext),
            ],
            cwd=secrets_root,
        )

    print(f"created encrypted secrets bundle: {target}")


def render() -> None:
    config = load_config()
    target_dir = output_dir(config)
    render_outputs(config, target_dir, output_types=("controlplane", "talosconfig"))

    print(f"rendered Talos outputs: {target_dir}")


def validate() -> None:
    config = load_config()
    rendered_dir = output_dir(config)
    controlplane = rendered_dir / "controlplane.yaml"
    talosconfig = rendered_dir / "talosconfig"

    if not controlplane.is_file():
        raise ClusterError(f"rendered control-plane config is missing: {controlplane}")
    if not talosconfig.is_file():
        raise ClusterError(f"rendered talosconfig is missing: {talosconfig}")

    run(
        [
            "talosctl",
            "validate",
            "--mode",
            "metal",
            "--strict",
            "--config",
            str(controlplane),
        ]
    )
    print(f"validated Talos config: {controlplane}")


def select_container_runtime() -> str:
    for runtime in ("docker", "podman"):
        if shutil.which(runtime) is not None:
            return runtime

    raise ClusterError("no container runtime available: expected docker or podman")


def ensure_command(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise ClusterError(f"required command is not available: {name}")

    return path


def post_schematic(schematic: Path) -> str:
    try:
        data = schematic.read_bytes()
    except OSError as exc:
        raise ClusterError(f"failed to read schematic file {schematic}: {exc}") from exc

    request = urllib.request.Request(
        IMAGE_FACTORY_URL,
        data=data,
        headers={"Content-Type": "application/yaml"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace").strip()
        message = body or exc.reason
        raise ClusterError(f"failed to upload schematic to Image Factory: HTTP {exc.code}: {message}") from exc
    except urllib.error.URLError as exc:
        raise ClusterError(f"failed to upload schematic to Image Factory: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise ClusterError("Image Factory response was not valid JSON") from exc

    schematic_id = payload.get("id")
    if not schematic_id:
        raise ClusterError("Image Factory response did not include a schematic id")

    return str(schematic_id)


def generate_iso() -> None:
    config = load_config()
    boot_assets = load_boot_assets(config)
    schematic = schematic_path(boot_assets)
    if not schematic.is_file():
        raise ClusterError(f"schematic file does not exist: {schematic}")

    render()

    runtime = select_container_runtime()
    schematic_id = post_schematic(schematic)
    installer_image = f"factory.talos.dev/installer/{schematic_id}:{config['talosVersion']}"
    imager_image = f"ghcr.io/siderolabs/imager:{config['talosVersion']}"
    assets_dir = boot_assets_dir(boot_assets)
    iso_name = f"{config['name']}-metal-{boot_assets['arch']}-{config['talosVersion']}.iso"

    with tempfile.TemporaryDirectory(prefix="platform-talos-iso-") as tmpdir:
        tmp_root = Path(tmpdir)
        embedded_render_dir = tmp_root / "embedded-render"
        imager_output_dir = tmp_root / "imager-output"
        staged_output_dir = tmp_root / "staged-output"

        render_outputs(
            config,
            embedded_render_dir,
            output_types=("controlplane",),
            install_image=installer_image,
        )

        embedded_config = embedded_render_dir / "controlplane.yaml"
        imager_output_dir.mkdir(parents=True, exist_ok=True)
        staged_output_dir.mkdir(parents=True, exist_ok=True)

        run(
            [
                runtime,
                "run",
                "--rm",
                "--privileged",
                "-v",
                f"{imager_output_dir}:/out",
                "-v",
                f"{embedded_config}:/work/controlplane.yaml:ro",
                imager_image,
                "metal",
                "--arch",
                str(boot_assets["arch"]),
                "--output-kind",
                "iso",
                "--base-installer-image",
                installer_image,
                "--embedded-config-path",
                "/work/controlplane.yaml",
            ]
        )

        staged_iso = staged_output_dir / iso_name
        generated_plain_isos = sorted(imager_output_dir.rglob("*.iso"))
        generated_compressed_isos = sorted(imager_output_dir.rglob("*.iso.zst"))
        if len(generated_plain_isos) == 1:
            shutil.copy2(generated_plain_isos[0], staged_iso)
        elif len(generated_plain_isos) == 0 and len(generated_compressed_isos) == 1:
            zstd = ensure_command("zstd")
            run([zstd, "-d", "--force", "-o", str(staged_iso), str(generated_compressed_isos[0])])
        else:
            raise ClusterError(
                "expected exactly one ISO artifact from imager"
                f" (found {len(generated_plain_isos)} plain and {len(generated_compressed_isos)} compressed)"
            )

        staged_patched_config = staged_output_dir / "controlplane.installer-patched.yaml"
        shutil.copy2(embedded_config, staged_patched_config)

        manifest = {
            "clusterName": config["name"],
            "talosVersion": config["talosVersion"],
            "kubernetesVersion": config["kubernetesVersion"],
            "schematicFile": str(schematic),
            "schematicId": schematic_id,
            "installerImage": installer_image,
            "imagerImage": imager_image,
            "outputIsoPath": str(assets_dir / iso_name),
            "canonicalEndpoint": config["endpoint"],
            "generatedAt": datetime.now(timezone.utc).isoformat(),
        }
        (staged_output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

        assets_dir.mkdir(parents=True, exist_ok=True)
        for staged_file in staged_output_dir.iterdir():
            os.replace(staged_file, assets_dir / staged_file.name)

    print(f"generated ISO artifacts: {assets_dir}")


if __name__ == "__main__":
    raise SystemExit(main())
