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
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import yaml


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONTROLPLANE_CONFIG = ROOT / ".state" / "rendered" / "controlplane.yaml"
DEFAULT_TALOSCONFIG = ROOT / ".state" / "rendered" / "talosconfig"
API_WAIT_TIMEOUT_SECONDS = int(os.environ.get("GLAB_TALOS_BOOTSTRAP_API_WAIT_SECONDS", "180"))
COMMAND_TIMEOUT_SECONDS = int(os.environ.get("GLAB_TALOS_BOOTSTRAP_COMMAND_TIMEOUT_SECONDS", "10"))
POLL_INTERVAL_SECONDS = float(os.environ.get("GLAB_TALOS_BOOTSTRAP_POLL_INTERVAL_SECONDS", "2"))
BOOTSTRAP_TIMEOUT_SECONDS = int(os.environ.get("GLAB_TALOS_BOOTSTRAP_ACTION_TIMEOUT_SECONDS", "60"))


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
        wait_for_api(args.talosconfig, node_ip)
        if is_bootstrapped(args.talosconfig, node_ip):
            print(f"cluster already bootstrapped at {node_ip}", flush=True)
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
        documents = [doc for doc in yaml.safe_load_all(fh) if isinstance(doc, dict)]

    if not documents:
        raise BootstrapError(f"rendered control-plane config has no YAML mapping documents: {path}")

    for data in documents:
        addresses = data.get("addresses")
        if not isinstance(addresses, list):
            continue

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


def run_talosctl(
    talosconfig: Path,
    node_ip: str,
    *args: str,
    timeout: float,
    check: bool,
) -> subprocess.CompletedProcess[str]:
    cmd = talosctl_cmd(talosconfig, node_ip, *args)
    try:
        return subprocess.run(
            cmd,
            text=True,
            capture_output=True,
            check=check,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise BootstrapError(
            f"{' '.join(cmd)} timed out after {timeout:.0f}s; "
            f"Talos API at {node_ip} is not responding yet"
        ) from exc
    except subprocess.CalledProcessError as exc:
        details = command_error_details(exc.stdout, exc.stderr)
        suffix = f": {details}" if details else ""
        raise BootstrapError(f"{' '.join(cmd)} exited with status {exc.returncode}{suffix}") from exc


def wait_for_api(talosconfig: Path, node_ip: str) -> None:
    print(f"waiting for Talos API at {node_ip} (up to {API_WAIT_TIMEOUT_SECONDS}s)", flush=True)
    deadline = time.monotonic() + API_WAIT_TIMEOUT_SECONDS
    last_error: str | None = None

    while time.monotonic() < deadline:
        cmd = talosctl_cmd(talosconfig, node_ip, "version")
        try:
            result = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                check=False,
                timeout=COMMAND_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            last_error = f"{' '.join(cmd)} timed out after {COMMAND_TIMEOUT_SECONDS}s"
        else:
            if result.returncode == 0:
                print(f"Talos API reachable at {node_ip}", flush=True)
                return
            last_error = format_result_error(result.stdout, result.stderr)

        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(POLL_INTERVAL_SECONDS, remaining))

    suffix = f": {last_error}" if last_error else ""
    raise BootstrapError(
        f"timed out waiting for Talos API at {node_ip} after {API_WAIT_TIMEOUT_SECONDS}s{suffix}"
    )


def is_bootstrapped(talosconfig: Path, node_ip: str) -> bool:
    result = run_talosctl(
        talosconfig,
        node_ip,
        "etcd",
        "members",
        timeout=COMMAND_TIMEOUT_SECONDS,
        check=False,
    )
    return result.returncode == 0


def bootstrap(talosconfig: Path, node_ip: str) -> None:
    print(f"bootstrapping control plane at {node_ip}", flush=True)
    run_talosctl(
        talosconfig,
        node_ip,
        "bootstrap",
        timeout=BOOTSTRAP_TIMEOUT_SECONDS,
        check=True,
    )


def format_result_error(stdout: str, stderr: str) -> str:
    return command_error_details(stdout, stderr) or "command failed without output"


def command_error_details(stdout: str, stderr: str) -> str:
    return stderr.strip() or stdout.strip()


if __name__ == "__main__":
    sys.exit(main())
