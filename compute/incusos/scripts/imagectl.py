#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyYAML>=6.0,<7",
# ]
# ///
"""Build and stage the IncusOS operation image from CUE-exported config."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from typing import Any
import urllib.request

import yaml


ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = ROOT / ".state"
DOWNLOADS_DIR = STATE_DIR / "downloads"
IMAGES_DIR = STATE_DIR / "images"
DEFAULT_VYOS_HOST = "10.0.0.2"
DEFAULT_VYOS_SSH_KEY = "~/.ssh/vyos-gateway"
DEFAULT_VYOS_USER = "vyos"


class ImageError(RuntimeError):
    """Raised when image configuration or build steps fail."""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("build", help="Build the seeded IncusOS operation image")
    subparsers.add_parser("stage-vyos", help="Stage the built image to the VyOS artifact directory")
    args = parser.parse_args()

    try:
        config = load_config()
        if args.command == "build":
            build_image(config)
        elif args.command == "stage-vyos":
            stage_image_to_vyos(config)
        else:
            raise ImageError(f"unsupported command: {args.command}")
    except ImageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


def load_config() -> dict[str, Any]:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        raise ImageError(f"failed to parse image config JSON from stdin: {exc}") from exc

    if not isinstance(data, dict):
        raise ImageError("image config must be a JSON object")

    require_mapping(data, "host")
    require_mapping(data, "provisioning")
    require_mapping(data, "image")
    require_mapping(data, "identity")
    require_mapping(data, "router")
    return data


def require_mapping(data: dict[str, Any], key: str) -> dict[str, Any]:
    value = data.get(key)
    if not isinstance(value, dict):
        raise ImageError(f"image config is missing required object: {key}")
    return value


def build_image(config: dict[str, Any]) -> None:
    host = require_mapping(config, "host")
    image = require_mapping(config, "image")
    identity_cfg = require_mapping(config, "identity")

    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    metadata = current_image_metadata(image)
    archive_path = DOWNLOADS_DIR / metadata["filename"]
    download_file(metadata["url"], archive_path)
    verify_sha256(archive_path, metadata["sha256"])

    identity = load_identity(identity_cfg["secretsFile"])
    artifact_name = require_string(image, "artifactName")
    artifact_url = require_string(image, "artifactURL")
    raw_path = IMAGES_DIR / artifact_name.removesuffix(".gz")
    artifact_path = IMAGES_DIR / artifact_name
    seed_bytes = build_seed_tar(identity)

    with gzip.open(archive_path, "rb") as compressed, raw_path.open("wb") as raw_handle:
        shutil.copyfileobj(compressed, raw_handle)

    with raw_path.open("r+b") as raw_handle:
        raw_handle.truncate(parse_size(require_string(image, "size")))
        raw_handle.seek(require_int(image, "seedOffset"))
        raw_handle.write(seed_bytes)

    (IMAGES_DIR / f"{host['name']}-client.crt").write_text(identity["client_crt_pem"], encoding="utf-8")
    (IMAGES_DIR / f"{host['name']}-client.key").write_text(identity["client_key_pem"], encoding="utf-8")

    with raw_path.open("rb") as source, gzip.GzipFile(
        filename="",
        mode="wb",
        fileobj=artifact_path.open("wb"),
        compresslevel=1,
        mtime=0,
    ) as destination:
        shutil.copyfileobj(source, destination)

    env_path = IMAGES_DIR / f"{host['name']}.env"
    env_path.write_text(
        "\n".join(
            [
                f"ARTIFACT_NAME={artifact_name}",
                f"ARTIFACT_PATH={artifact_path}",
                f"ARTIFACT_URL={artifact_url}",
                f"INCUSOS_VERSION={metadata['version']}",
                f"SOURCE_URL={metadata['url']}",
                f"SOURCE_SHA256={metadata['sha256']}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(artifact_path)


def stage_image_to_vyos(config: dict[str, Any]) -> None:
    image = require_mapping(config, "image")
    router = require_mapping(config, "router")

    artifact_path = IMAGES_DIR / require_string(image, "artifactName")
    if not artifact_path.is_file():
        raise ImageError(f"built artifact does not exist: {artifact_path}")

    vyos_host = os.environ.get("VYOS_HOST", DEFAULT_VYOS_HOST)
    ssh_key = os.path.expanduser(os.environ.get("VYOS_SSH_KEY", DEFAULT_VYOS_SSH_KEY))
    vyos_user = os.environ.get("VYOS_USER", DEFAULT_VYOS_USER)
    remote_dir = require_string(router, "artifactDir")
    remote_name = artifact_path.name
    remote_tmp = f"{vyos_user}@{vyos_host}:~/{remote_name}"

    ssh_prefix = [
        "ssh",
        "-i",
        ssh_key,
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        f"{vyos_user}@{vyos_host}",
    ]
    run(ssh_prefix + [f"sudo install -d -m 0755 {remote_dir}"])
    run(
        [
            "scp",
            "-i",
            ssh_key,
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            str(artifact_path),
            remote_tmp,
        ]
    )
    run(ssh_prefix + [f"sudo install -m 0644 ~/{remote_name} {remote_dir}/{remote_name} && rm -f ~/{remote_name}"])


def current_image_metadata(image: dict[str, Any]) -> dict[str, str]:
    index_url = require_string(image, "indexURL")
    arch = require_string(image, "arch")
    base_url = require_string(image, "baseURL")

    with urllib.request.urlopen(index_url) as response:
        data = json.loads(response.read().decode("utf-8"))

    for update in data.get("updates", []):
        if "stable" not in update.get("channels", []):
            continue
        for file_info in update.get("files", []):
            if (
                file_info.get("architecture") == arch
                and file_info.get("component") == "os"
                and file_info.get("type") == "image-raw"
            ):
                return {
                    "version": update["version"],
                    "url": f"{base_url}{update['url']}/{file_info['filename']}",
                    "filename": file_info["filename"],
                    "sha256": file_info["sha256"],
                }
    raise ImageError("could not find a stable IncusOS raw image for the configured architecture")


def load_identity(secret_file: str) -> dict[str, str]:
    raw = os.environ.get("GLAB_SECRETS_DIR")
    if not raw:
        raise ImageError("GLAB_SECRETS_DIR is not set")

    secrets_root = Path(raw).expanduser().resolve()
    if not secrets_root.is_dir():
        raise ImageError(f"GLAB_SECRETS_DIR does not exist: {secrets_root}")

    secret_path = secrets_root / secret_file
    result = run(["sops", "-d", str(secret_path)], capture_output=True)
    data = yaml.safe_load(result.stdout)
    if not isinstance(data, dict):
        raise ImageError(f"decrypted identity file is not a mapping: {secret_path}")

    required = ("client_name", "client_crt_pem", "client_key_pem")
    missing = [field for field in required if not data.get(field)]
    if missing:
        raise ImageError(f"{secret_path} is missing required field(s): {', '.join(missing)}")
    return data


def build_seed_tar(identity: dict[str, str]) -> bytes:
    buffer = io.BytesIO()
    applications_yaml = 'version: "1"\napplications:\n  - name: incus\n'
    incus_yaml = (
        'version: "1"\n'
        "apply_defaults: true\n"
        "preseed:\n"
        "  certificates:\n"
        f"    - name: {identity['client_name']}\n"
        "      type: client\n"
        "      certificate: |\n"
        f"{indent_block(identity['client_crt_pem'].rstrip())}\n"
    )

    with tarfile.open(fileobj=buffer, mode="w") as archive:
        add_bytes_to_tar(archive, "applications.yaml", applications_yaml.encode("utf-8"))
        add_bytes_to_tar(archive, "incus.yaml", incus_yaml.encode("utf-8"))

    return buffer.getvalue()


def add_bytes_to_tar(archive: tarfile.TarFile, name: str, payload: bytes) -> None:
    info = tarfile.TarInfo(name=name)
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))


def indent_block(payload: str) -> str:
    return "\n".join(f"        {line}" for line in payload.splitlines())


def download_file(url: str, destination: Path) -> None:
    if destination.is_file():
        return
    with urllib.request.urlopen(url) as response, destination.open("wb") as handle:
        shutil.copyfileobj(response, handle)


def verify_sha256(path: Path, expected: str) -> None:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual != expected:
        raise ImageError(f"sha256 mismatch for {path}: expected {expected}, got {actual}")


def parse_size(size: str) -> int:
    size = size.strip().upper()
    suffixes = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
    if size[-1] in suffixes:
        return int(size[:-1]) * suffixes[size[-1]]
    return int(size)


def require_string(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str) or value == "":
        raise ImageError(f"image config field must be a non-empty string: {key}")
    return value


def require_int(data: dict[str, Any], key: str) -> int:
    value = data.get(key)
    if not isinstance(value, int):
        raise ImageError(f"image config field must be an int: {key}")
    return value


def run(cmd: list[str], *, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            check=True,
            text=True,
            capture_output=capture_output,
        )
    except subprocess.CalledProcessError as exc:
        message = exc.stderr or exc.stdout or "command failed"
        raise ImageError(f"{' '.join(cmd)}: {message.strip()}") from exc


if __name__ == "__main__":
    raise SystemExit(main())
