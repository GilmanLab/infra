#!/usr/bin/env python3
"""Converge PowerDNS zones, rrsets, TSIG keys, and metadata via the HTTP API."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


MANAGED_METADATA_KINDS = {
    "ALLOW-DNSUPDATE-FROM",
    "FORWARD-DNSUPDATE",
    "NOTIFY-DNSUPDATE",
    "SOA-EDIT-DNSUPDATE",
    "TSIG-ALLOW-DNSUPDATE",
}
ZONE_TYPES_WITH_FQDN_CONTENT = {"CNAME", "NS", "PTR"}


class ApiError(RuntimeError):
    """PowerDNS API request failed."""


def normalize_name(value: str) -> str:
    return value if value.endswith(".") else f"{value}."


def normalize_metadata(values: list[str]) -> list[str]:
    return sorted(dict.fromkeys(values))


def normalize_record_content(rrtype: str, content: str) -> str:
    if rrtype in ZONE_TYPES_WITH_FQDN_CONTENT:
        return normalize_name(content)
    return content


def normalize_rrset(rrset: dict[str, Any]) -> tuple[int | None, tuple[tuple[str, bool], ...]]:
    ttl = rrset.get("ttl")
    records = tuple(
        sorted(
            (
                normalize_record_content(rrset["type"].upper(), record["content"]),
                bool(record.get("disabled", False)),
            )
            for record in rrset.get("records", [])
        )
    )
    return ttl, records


def build_request(base_url: str, api_key: str, method: str, path: str, payload: Any | None = None) -> urllib.request.Request:
    url = f"{base_url}{path}"
    data = None
    headers = {"X-API-Key": api_key}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    return urllib.request.Request(url, data=data, headers=headers, method=method)


def api_request(base_url: str, api_key: str, method: str, path: str, payload: Any | None = None, expected: tuple[int, ...] = (200,)) -> Any:
    request = build_request(base_url, api_key, method, path, payload)
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read()
            if response.status not in expected:
                raise ApiError(f"{method} {path} returned unexpected status {response.status}")
            if not body:
                return None
            return json.loads(body.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise ApiError(f"{method} {path} failed with {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise ApiError(f"{method} {path} failed: {exc}") from exc


def ensure_tsig_keys(base_url: str, api_key: str, server_id: str, desired_keys: list[dict[str, str]]) -> None:
    current_keys = api_request(base_url, api_key, "GET", f"/servers/{server_id}/tsigkeys")
    current_by_name = {key["name"]: key for key in current_keys}

    for desired in desired_keys:
        current = current_by_name.get(desired["name"])
        if current is None:
            api_request(
                base_url,
                api_key,
                "POST",
                f"/servers/{server_id}/tsigkeys",
                payload=desired,
                expected=(201,),
            )
            print(f"created TSIG key {desired['name']}")
            continue

        current_full = api_request(
            base_url,
            api_key,
            "GET",
            f"/servers/{server_id}/tsigkeys/{urllib.parse.quote(current['id'], safe='')}",
        )
        if current_full.get("algorithm") != desired["algorithm"] or current_full.get("key") != desired["key"]:
            api_request(
                base_url,
                api_key,
                "PUT",
                f"/servers/{server_id}/tsigkeys/{urllib.parse.quote(current['id'], safe='')}",
                payload=desired,
            )
            print(f"updated TSIG key {desired['name']}")


def ensure_zone(base_url: str, api_key: str, server_id: str, zone: dict[str, Any], current_zones: dict[str, dict[str, Any]]) -> str:
    current = current_zones.get(zone["name"])
    if current is None:
        created = api_request(
            base_url,
            api_key,
            "POST",
            f"/servers/{server_id}/zones",
            payload={
                "name": zone["name"],
                "kind": zone.get("kind", "Native"),
                "nameservers": zone.get("nameservers", []),
            },
            expected=(201,),
        )
        print(f"created zone {zone['name']}")
        return created["id"]

    zone_id = current["id"]
    if current.get("kind") != zone.get("kind", "Native"):
        api_request(
            base_url,
            api_key,
            "PATCH",
            f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}",
            payload={"kind": zone.get("kind", "Native")},
            expected=(200, 204),
        )
        print(f"updated zone kind for {zone['name']}")
    return zone_id


def ensure_rrsets(base_url: str, api_key: str, server_id: str, zone_id: str, desired_zone: dict[str, Any]) -> None:
    current_zone = api_request(
        base_url,
        api_key,
        "GET",
        f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}?rrsets=true",
    )
    current_rrsets = {(rrset["name"], rrset["type"].upper()): rrset for rrset in current_zone.get("rrsets", [])}
    desired_rrsets = {(rrset["name"], rrset["type"].upper()): rrset for rrset in desired_zone.get("rrsets", [])}
    changes = []

    for key, desired_rrset in desired_rrsets.items():
        current_rrset = current_rrsets.get(key)
        if current_rrset is None or normalize_rrset(current_rrset) != normalize_rrset(desired_rrset):
            changes.append(
                {
                    "name": desired_rrset["name"],
                    "type": desired_rrset["type"].upper(),
                    "ttl": desired_rrset["ttl"],
                    "changetype": "REPLACE",
                    "records": desired_rrset["records"],
                }
            )

    if desired_zone.get("prune_unmanaged_rrsets", False):
        for key, current_rrset in current_rrsets.items():
            if current_rrset["type"].upper() == "SOA":
                continue
            if key not in desired_rrsets:
                changes.append(
                    {
                        "name": current_rrset["name"],
                        "type": current_rrset["type"].upper(),
                        "changetype": "DELETE",
                    }
                )

    if changes:
        api_request(
            base_url,
            api_key,
            "PATCH",
            f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}",
            payload={"rrsets": changes},
            expected=(200, 204),
        )
        print(f"updated rrsets for {desired_zone['name']}")


def ensure_metadata(base_url: str, api_key: str, server_id: str, zone_id: str, desired_zone: dict[str, Any]) -> None:
    metadata_items = api_request(
        base_url,
        api_key,
        "GET",
        f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}/metadata",
    )
    current_metadata = {
        item["kind"]: normalize_metadata(item.get("metadata", []))
        for item in metadata_items
        if item["kind"] in MANAGED_METADATA_KINDS
    }
    desired_metadata = {
        kind: normalize_metadata(values)
        for kind, values in desired_zone.get("metadata", {}).items()
    }

    for kind, values in desired_metadata.items():
        if current_metadata.get(kind) != values:
            api_request(
                base_url,
                api_key,
                "PUT",
                f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}/metadata/{urllib.parse.quote(kind, safe='')}",
                payload={"kind": kind, "metadata": values},
            )
            print(f"updated metadata {kind} for {desired_zone['name']}")

    for kind in sorted(current_metadata):
        if kind not in desired_metadata:
            api_request(
                base_url,
                api_key,
                "DELETE",
                f"/servers/{server_id}/zones/{urllib.parse.quote(zone_id, safe='')}/metadata/{urllib.parse.quote(kind, safe='')}",
                expected=(200, 204),
            )
            print(f"deleted metadata {kind} for {desired_zone['name']}")


def load_desired_state(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    for zone in data.get("zones", []):
        zone["name"] = normalize_name(zone["name"])
        zone["nameservers"] = [normalize_name(item) for item in zone.get("nameservers", [])]
        for rrset in zone.get("rrsets", []):
            rrset["name"] = normalize_name(rrset["name"])
            rrset["type"] = rrset["type"].upper()
            for record in rrset.get("records", []):
                record["content"] = normalize_record_content(rrset["type"], record["content"])
                record["disabled"] = bool(record.get("disabled", False))
    return data


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: pdns-reconcile.py <desired-state.json>", file=sys.stderr)
        return 2

    api_key = os.environ.get("PDNS_API_KEY")
    if not api_key:
        print("PDNS_API_KEY is required", file=sys.stderr)
        return 2

    desired = load_desired_state(sys.argv[1])
    base_url = os.environ.get("PDNS_API_URL", "http://127.0.0.1:8081/api/v1").rstrip("/")
    server_id = desired.get("server_id", "localhost")

    ensure_tsig_keys(base_url, api_key, server_id, desired.get("tsig_keys", []))
    current_zones = api_request(base_url, api_key, "GET", f"/servers/{server_id}/zones?rrsets=false")
    current_by_name = {zone["name"]: zone for zone in current_zones}

    for zone in desired.get("zones", []):
        zone_id = ensure_zone(base_url, api_key, server_id, zone, current_by_name)
        ensure_rrsets(base_url, api_key, server_id, zone_id, zone)
        ensure_metadata(base_url, api_key, server_id, zone_id, zone)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ApiError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
