#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyYAML>=6.0,<7",
# ]
# ///
"""Bootstrap the platform Talos cluster if it is not already bootstrapped."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

import yaml


ROOT = Path(__file__).resolve().parent
DEFAULT_CONTROLPLANE_CONFIG = ROOT / ".state" / "rendered" / "controlplane.yaml"
DEFAULT_TALOSCONFIG = ROOT / ".state" / "rendered" / "talosconfig"


class BootstrapError(RuntimeError):
    """Raised when bootstrap prerequisites are not met."""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--controlplane-config",
        default=DEFAULT_CONTROLPLANE_CONFIG,
        type=Path,
        help="Path to the rendered control-plane machine config",
    )
    parser.add_argument(
        "--talosconfig",
        default=DEFAULT_TALOSCONFIG,
        type=Path,
        help="Path to the rendered talosconfig",
    )
    args = parser.parse_args()

    try:
        ensure_talosctl()
        ensure_file(args.controlplane_config, "rendered control-plane config")
        ensure_file(args.talosconfig, "talosconfig")
        node_ip = control_plane_ip(args.controlplane_config)
        if is_bootstrapped(args.talosconfig, node_ip):
            print(f"cluster already bootstrapped at {node_ip}")
        else:
            bootstrap(args.talosconfig, node_ip)
    except BootstrapError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


def ensure_talosctl() -> None:
    if shutil.which("talosctl") is None:
        raise BootstrapError("missing required tool: talosctl")


def ensure_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise BootstrapError(f"{label} does not exist: {path}")


def control_plane_ip(path: Path) -> str:
    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    if not isinstance(data, dict):
        raise BootstrapError(f"rendered control-plane config is not a mapping: {path}")

    addresses = data.get("addresses")
    if not isinstance(addresses, list):
        raise BootstrapError(f"rendered control-plane config has no addresses list: {path}")

    for entry in addresses:
        if not isinstance(entry, dict):
            continue
        address = entry.get("address")
        if isinstance(address, str) and address:
            return address.split("/", 1)[0]

    raise BootstrapError(f"failed to determine control-plane IP from {path}")


def talosctl_cmd(talosconfig: Path, node_ip: str, *args: str) -> list[str]:
    return [
        "talosctl",
        "--talosconfig",
        str(talosconfig),
        "-e",
        node_ip,
        "-n",
        node_ip,
        *args,
    ]


def is_bootstrapped(talosconfig: Path, node_ip: str) -> bool:
    result = subprocess.run(
        talosctl_cmd(talosconfig, node_ip, "etcd", "members"),
        text=True,
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def bootstrap(talosconfig: Path, node_ip: str) -> None:
    cmd = talosctl_cmd(talosconfig, node_ip, "bootstrap")
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        raise BootstrapError(f"{' '.join(cmd)} exited with status {exc.returncode}") from exc


if __name__ == "__main__":
    sys.exit(main())
