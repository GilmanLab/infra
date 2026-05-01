#!/usr/bin/env python3
"""Switch the UM760-facing VyOS link between management and PXE provisioning."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_VYOS_HOST = "10.0.0.2"
DEFAULT_VYOS_USER = "vyos"
DEFAULT_VYOS_SSH_KEY = "~/.ssh/vyos-gateway"

BR_MGMT = "br10"
BR_PROV = "br20"
IFACE_DIRECT = "eth2"
IFACE_MGMT = "eth2.10"
VIF_MGMT = "10"

UM760_MAC = "38:05:25:34:25:d0"
UM760_MGMT_IP = "10.10.10.10"
UM760_PROV_IP = "10.10.20.10"

LISTENER_PORTS = ("67", "69", "514")


@dataclass(frozen=True)
class LinkStatus:
    mode: str
    br10_members: list[str]
    br20_members: list[str]
    eth2_vif10_present: bool
    um760_fdb: list[str]
    um760_neighbors: list[str]
    listeners: list[str]


class CommandError(RuntimeError):
    def __init__(self, command: str, result: subprocess.CompletedProcess[str]) -> None:
        super().__init__(f"command failed ({result.returncode}): {command}\n{result.stderr.strip()}")
        self.command = command
        self.result = result


class VyOSClient:
    def __init__(self, host: str, user: str, ssh_key: str, ssh_opts: str) -> None:
        self.host = host
        self.user = user
        self.ssh_key = str(Path(ssh_key).expanduser())
        self.ssh_opts = shlex.split(ssh_opts)

    def run(self, remote_command: str, *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        command = [
            "ssh",
            "-i",
            self.ssh_key,
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "-o",
            "StrictHostKeyChecking=accept-new",
            *self.ssh_opts,
            f"{self.user}@{self.host}",
            remote_command,
        ]
        result = subprocess.run(
            command,
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if check and result.returncode != 0:
            raise CommandError(" ".join(shlex.quote(part) for part in command), result)
        return result

    def read_config_commands(self) -> str:
        command = f"/bin/vbash -ic {shlex.quote('show configuration commands')}"
        return self.run(command).stdout

    def apply_config_commands(self, commands: list[str]) -> None:
        script = "\n".join(
            [
                "source /opt/vyatta/etc/functions/script-template",
                "configure",
                *commands,
                "commit",
                "save",
                "exit",
                "exit",
            ]
        )
        self.run("/bin/vbash -s", input_text=f"{script}\n")


def bridge_members(config: str, bridge: str) -> list[str]:
    pattern = re.compile(rf"^set interfaces bridge {re.escape(bridge)} member interface '?([^'\s]+)'?", re.MULTILINE)
    return sorted(set(pattern.findall(config)))


def bridge_exists(config: str, bridge: str) -> bool:
    return any(line.startswith(f"set interfaces bridge {bridge}") for line in config.splitlines())


def eth2_vif10_present(config: str) -> bool:
    return any(line.startswith(f"set interfaces ethernet {IFACE_DIRECT} vif {VIF_MGMT}") for line in config.splitlines())


def infer_mode(br10_members: Iterable[str], br20_members: Iterable[str]) -> str:
    has_mgmt = IFACE_MGMT in set(br10_members)
    has_prov = IFACE_DIRECT in set(br20_members)
    if has_mgmt and not has_prov:
        return "mgmt"
    if has_prov and not has_mgmt:
        return "provision"
    if has_mgmt and has_prov:
        return "mixed"
    return "unknown"


def collect_status(client: VyOSClient) -> LinkStatus:
    config = client.read_config_commands()
    br10 = bridge_members(config, BR_MGMT)
    br20 = bridge_members(config, BR_PROV)

    fdb = client.run("sudo /usr/sbin/bridge fdb show 2>/dev/null || sudo bridge fdb show", check=False).stdout
    neigh = client.run("sudo /usr/sbin/ip neigh show 2>/dev/null || sudo ip neigh show", check=False).stdout
    listeners = client.run("sudo /usr/bin/ss -H -lunp 2>/dev/null || sudo /usr/sbin/ss -H -lunp", check=False).stdout

    listener_pattern = re.compile(r":(" + "|".join(re.escape(port) for port in LISTENER_PORTS) + r")(\s|$)")
    return LinkStatus(
        mode=infer_mode(br10, br20),
        br10_members=br10,
        br20_members=br20,
        eth2_vif10_present=eth2_vif10_present(config),
        um760_fdb=[line for line in fdb.splitlines() if UM760_MAC in line.lower()],
        um760_neighbors=[
            line
            for line in neigh.splitlines()
            if UM760_MAC in line.lower() or UM760_MGMT_IP in line or UM760_PROV_IP in line
        ],
        listeners=[line for line in listeners.splitlines() if listener_pattern.search(line)],
    )


def print_status(status: LinkStatus) -> None:
    def render_members(members: list[str]) -> str:
        return ", ".join(members) if members else "(none)"

    print(f"UM760 link mode: {status.mode}")
    print(f"{BR_MGMT} members: {render_members(status.br10_members)}")
    print(f"{BR_PROV} members: {render_members(status.br20_members)}")
    print(f"{IFACE_DIRECT} vif {VIF_MGMT} present: {'yes' if status.eth2_vif10_present else 'no'}")
    print()
    print(f"UM760 MAC/IP evidence ({UM760_MAC}, {UM760_MGMT_IP}, {UM760_PROV_IP}):")
    if status.um760_fdb:
        for line in status.um760_fdb:
            print(f"  fdb: {line}")
    else:
        print("  fdb: not observed")
    if status.um760_neighbors:
        for line in status.um760_neighbors:
            print(f"  neigh: {line}")
    else:
        print("  neigh: not observed")
    print()
    print("DHCP/PXE/syslog UDP listeners (:67, :69, :514):")
    if status.listeners:
        for line in status.listeners:
            print(f"  {line}")
    else:
        print("  none observed")


def provision_commands(config: str) -> list[str]:
    if not bridge_exists(config, BR_PROV):
        raise RuntimeError(f"{BR_PROV} is not configured; deploy the durable VyOS bridge config before flipping the link")

    commands: list[str] = []
    if IFACE_MGMT in bridge_members(config, BR_MGMT):
        commands.append(f"delete interfaces bridge {BR_MGMT} member interface {IFACE_MGMT}")
    if eth2_vif10_present(config):
        commands.append(f"delete interfaces ethernet {IFACE_DIRECT} vif {VIF_MGMT}")
    if IFACE_DIRECT not in bridge_members(config, BR_PROV):
        commands.append(f"set interfaces bridge {BR_PROV} member interface {IFACE_DIRECT}")
    return commands


def mgmt_commands(config: str) -> list[str]:
    if not bridge_exists(config, BR_MGMT):
        raise RuntimeError(f"{BR_MGMT} is not configured; cannot restore the UM760 management link")

    commands: list[str] = []
    if IFACE_DIRECT in bridge_members(config, BR_PROV):
        commands.append(f"delete interfaces bridge {BR_PROV} member interface {IFACE_DIRECT}")
    if not eth2_vif10_present(config):
        commands.append(f"set interfaces ethernet {IFACE_DIRECT} vif {VIF_MGMT} description 'LAB_MGMT - Bridge member (br10)'")
    if IFACE_MGMT not in bridge_members(config, BR_MGMT):
        commands.append(f"set interfaces bridge {BR_MGMT} member interface {IFACE_MGMT}")
    return commands


def run_transition(client: VyOSClient, target: str, dry_run: bool) -> None:
    config = client.read_config_commands()
    commands = provision_commands(config) if target == "provision" else mgmt_commands(config)

    if not commands:
        print(f"UM760 link is already in {target} mode; no changes needed.")
        return

    if dry_run:
        print("\n".join(["configure", *commands, "commit", "save", "exit"]))
        return

    client.apply_config_commands(commands)
    print(f"UM760 link switched to {target} mode.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=os.environ.get("VYOS_HOST", DEFAULT_VYOS_HOST))
    parser.add_argument("--user", default=os.environ.get("VYOS_USER", DEFAULT_VYOS_USER))
    parser.add_argument("--ssh-key", default=os.environ.get("VYOS_SSH_KEY", DEFAULT_VYOS_SSH_KEY))
    parser.add_argument("--ssh-opts", default=os.environ.get("VYOS_SSH_OPTS", ""))

    subparsers = parser.add_subparsers(dest="command", required=True)

    status = subparsers.add_parser("status", help="report current UM760 link mode and PXE ownership")
    status.add_argument("--json", action="store_true", help="emit status as JSON")

    provision = subparsers.add_parser("provision", help="move physical eth2 into LAB_PROV/br20 for PXE")
    provision.add_argument("--dry-run", action="store_true", help="print VyOS config commands without applying them")

    mgmt = subparsers.add_parser("mgmt", help="restore eth2.10 into LAB_MGMT/br10")
    mgmt.add_argument("--dry-run", action="store_true", help="print VyOS config commands without applying them")

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    client = VyOSClient(args.host, args.user, args.ssh_key, args.ssh_opts)

    try:
        if args.command == "status":
            status = collect_status(client)
            if args.json:
                print(json.dumps(asdict(status), indent=2, sort_keys=True))
            else:
                print_status(status)
            return 0

        run_transition(client, args.command, args.dry_run)
        return 0
    except (CommandError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
