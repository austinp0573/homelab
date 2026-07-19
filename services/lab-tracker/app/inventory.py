"""Load and save inventory.yml."""

from __future__ import annotations

import hashlib
import os
import shutil
import threading
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml

DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
INVENTORY_PATH = DATA_DIR / "inventory.yml"
BACKUP_PATH = DATA_DIR / "inventory.yml.bak"

_lock = threading.Lock()

EMPTY = {
    "version": 1,
    "custom_fields": [],
    "assets": [],
}

ASSET_TYPES = {
    "physical",
    "vm",
    "vps",
    "lxc",
    "nas",
    "switch",
    "ap",
    "ups",
    "pi",
    "gpu",
    "service",
    "network",
    "backup_job",
    "other",
}

STATUSES = {
    "draft",
    "planned",
    "active",
    "maintenance",
    "inactive",
    "retired",
}


class InventoryError(Exception):
    def __init__(self, message: str, fix: str = ""):
        super().__init__(message)
        self.message = message
        self.fix = fix


def _file_hash(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not INVENTORY_PATH.exists():
        dumped = yaml.safe_dump(
            deepcopy(EMPTY),
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
            width=1000,
        )
        INVENTORY_PATH.write_text(dumped, encoding="utf-8")


def read_raw() -> tuple[dict[str, Any], str]:
    ensure_data_dir()
    raw = INVENTORY_PATH.read_bytes()
    data = yaml.safe_load(raw) or deepcopy(EMPTY)
    if not isinstance(data, dict):
        raise InventoryError(
            "inventory.yml root must be a mapping",
            "fix the file so it starts with version/custom_fields/assets keys",
        )
    return data, _file_hash(raw)


def validate_inventory(data: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(data, dict):
        raise InventoryError(
            "inventory must be an object",
            "send a JSON object with version, custom_fields, and assets",
        )

    out = {
        "version": int(data.get("version") or 1),
        "custom_fields": [],
        "assets": [],
    }

    custom_fields = data.get("custom_fields") or []
    if not isinstance(custom_fields, list):
        raise InventoryError(
            "custom_fields must be a list",
            "use a YAML list under custom_fields",
        )

    seen_field_keys: set[str] = set()
    for i, field in enumerate(custom_fields):
        if not isinstance(field, dict):
            raise InventoryError(
                f"custom_fields[{i}] must be an object",
                "each custom field needs key, label, and category",
            )
        key = str(field.get("key") or "").strip()
        label = str(field.get("label") or "").strip()
        category = str(field.get("category") or "other").strip() or "other"
        if not key:
            raise InventoryError(
                f"custom_fields[{i}] is missing key",
                "set a non-empty key (letters, numbers, underscore)",
            )
        if key in seen_field_keys:
            raise InventoryError(
                f"duplicate custom field key '{key}'",
                "each custom field key must be unique",
            )
        if not label:
            label = key
        seen_field_keys.add(key)
        out["custom_fields"].append(
            {"key": key, "label": label, "category": category}
        )

    assets = data.get("assets") or []
    if not isinstance(assets, list):
        raise InventoryError(
            "assets must be a list",
            "use a YAML list under assets",
        )

    seen_ids: set[str] = set()
    seen_names: set[str] = set()
    for i, asset in enumerate(assets):
        if not isinstance(asset, dict):
            raise InventoryError(
                f"assets[{i}] must be an object",
                "each asset needs at least id, name, and type",
            )
        cleaned = _validate_asset(asset, i)
        if cleaned["id"] in seen_ids:
            raise InventoryError(
                f"duplicate asset id '{cleaned['id']}'",
                "every asset id must be unique",
            )
        name_key = cleaned["name"].lower()
        if name_key in seen_names:
            raise InventoryError(
                f"duplicate asset name '{cleaned['name']}'",
                "asset names must be unique (case-insensitive)",
            )
        seen_ids.add(cleaned["id"])
        seen_names.add(name_key)
        out["assets"].append(cleaned)

    id_set = {a["id"] for a in out["assets"]}
    for asset in out["assets"]:
        for field in (
            "parents",
            "powered_by",
            "backup_jobs",
            "depends_on",
            "backed_up_by",
            "fronted_by",
            "monitored_by",
        ):
            bad = [x for x in asset.get(field, []) if x not in id_set]
            if bad:
                raise InventoryError(
                    f"asset '{asset['name']}' has unknown id(s) in {field}: {', '.join(bad)}",
                    "point those fields at existing asset ids, or remove them",
                )

    return out


def _validate_asset(asset: dict[str, Any], index: int) -> dict[str, Any]:
    aid = str(asset.get("id") or "").strip()
    name = str(asset.get("name") or "").strip()
    atype = str(asset.get("type") or "").strip()
    status = str(asset.get("status") or "active").strip() or "active"

    if not aid:
        raise InventoryError(
            f"assets[{index}] is missing id",
            "set a unique id string on the asset",
        )
    if not name:
        raise InventoryError(
            f"asset '{aid}' is missing name",
            "set a non-empty name",
        )
    if atype not in ASSET_TYPES:
        raise InventoryError(
            f"asset '{name}' has invalid type '{atype}'",
            f"use one of: {', '.join(sorted(ASSET_TYPES))}",
        )
    if status not in STATUSES:
        raise InventoryError(
            f"asset '{name}' has invalid status '{status}'",
            f"use one of: {', '.join(sorted(STATUSES))}",
        )

    out: dict[str, Any] = {
        "id": aid,
        "name": name,
        "type": atype,
        "status": status,
    }

    def id_list(key: str) -> list[str]:
        val = asset.get(key) or []
        if not isinstance(val, list):
            raise InventoryError(
                f"asset '{name}' field '{key}' must be a list",
                f"use a YAML list of asset ids for {key}",
            )
        return [str(x).strip() for x in val if str(x).strip()]

    out["parents"] = id_list("parents")
    out["powered_by"] = id_list("powered_by")
    out["backup_jobs"] = id_list("backup_jobs")
    out["depends_on"] = id_list("depends_on")
    out["backed_up_by"] = id_list("backed_up_by")
    out["fronted_by"] = id_list("fronted_by")
    out["monitored_by"] = id_list("monitored_by")

    tags = asset.get("tags") or []
    if not isinstance(tags, list):
        raise InventoryError(
            f"asset '{name}' tags must be a list",
            "use a YAML list of strings for tags",
        )
    out["tags"] = [str(t).strip() for t in tags if str(t).strip()]

    for key in (
        "notes",
        "os",
        "hostname",
        "role",
        "location",
        "cpu",
        "ram",
        "disks",
        "gpu",
        "serial",
        "asset_tag",
        "purchase_date",
        "warranty",
        "ssh_user",
        "ssh_port",
        "mgmt_url",
        "tailscale",
        "wireguard",
        "secrets",
        "provider",
        "region",
        "cost",
        "hypervisor",
        "vmid",
        "storage_pool",
        "bridge",
        "model",
        "boot",
        "dns_names",
    ):
        if key in asset and asset[key] is not None and str(asset[key]).strip() != "":
            out[key] = str(asset[key]).strip()

    interfaces = asset.get("interfaces") or []
    if interfaces:
        if not isinstance(interfaces, list):
            raise InventoryError(
                f"asset '{name}' interfaces must be a list",
                "each interface is an object with name/mac/ips/network/role",
            )
        cleaned_ifaces = []
        for j, iface in enumerate(interfaces):
            if not isinstance(iface, dict):
                raise InventoryError(
                    f"asset '{name}' interfaces[{j}] must be an object",
                    "use name, mac, ips, network, role fields",
                )
            ips = iface.get("ips") or []
            if ips and not isinstance(ips, list):
                raise InventoryError(
                    f"asset '{name}' interfaces[{j}].ips must be a list",
                    "list IPv4/IPv6 addresses as strings",
                )
            entry = {}
            for k in ("name", "mac", "network", "role"):
                if iface.get(k):
                    entry[k] = str(iface[k]).strip()
            entry["ips"] = [str(x).strip() for x in ips if str(x).strip()]
            if any(entry.get(k) for k in ("name", "mac", "network", "role")) or entry["ips"]:
                cleaned_ifaces.append(entry)
        if cleaned_ifaces:
            out["interfaces"] = cleaned_ifaces

    ports = asset.get("ports") or []
    if ports:
        if not isinstance(ports, list):
            raise InventoryError(
                f"asset '{name}' ports must be a list",
                "each port is an object with label/port/protocol/note",
            )
        cleaned_ports = []
        for j, port in enumerate(ports):
            if not isinstance(port, dict):
                raise InventoryError(
                    f"asset '{name}' ports[{j}] must be an object",
                    "use label, port, protocol, note fields",
                )
            entry = {}
            for k in ("label", "port", "protocol", "note"):
                if port.get(k) is not None and str(port[k]).strip() != "":
                    entry[k] = str(port[k]).strip()
            if entry:
                cleaned_ports.append(entry)
        if cleaned_ports:
            out["ports"] = cleaned_ports

    custom = asset.get("custom") or {}
    if custom:
        if not isinstance(custom, dict):
            raise InventoryError(
                f"asset '{name}' custom must be a mapping",
                "use key: value pairs under custom",
            )
        out["custom"] = {
            str(k): ("" if v is None else str(v))
            for k, v in custom.items()
            if str(k).strip()
        }

    for key in (
        "parents",
        "powered_by",
        "backup_jobs",
        "depends_on",
        "backed_up_by",
        "fronted_by",
        "monitored_by",
        "tags",
    ):
        if key in out and not out[key]:
            del out[key]

    return out


def save_inventory(
    data: dict[str, Any],
    expected_hash: str | None,
) -> tuple[dict[str, Any], str]:
    with _lock:
        ensure_data_dir()
        current_raw = INVENTORY_PATH.read_bytes()
        current_hash = _file_hash(current_raw)
        if expected_hash is None:
            raise InventoryError(
                "missing expected_hash",
                "reload from disk and include the hash from GET /api/inventory",
            )
        if expected_hash != current_hash:
            raise InventoryError(
                "inventory.yml changed on disk",
                "click Reload from disk, re-apply your edits, then save again",
            )

        cleaned = validate_inventory(data)

        if INVENTORY_PATH.stat().st_size > 0:
            shutil.copyfile(INVENTORY_PATH, BACKUP_PATH)

        dumped = yaml.safe_dump(
            cleaned,
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
            width=1000,
        )
        tmp = INVENTORY_PATH.with_suffix(".yml.tmp")
        tmp.write_text(dumped, encoding="utf-8")
        tmp.replace(INVENTORY_PATH)
        new_hash = _file_hash(INVENTORY_PATH.read_bytes())
        return cleaned, new_hash


def get_inventory() -> tuple[dict[str, Any], str]:
    with _lock:
        data, file_hash = read_raw()
        # validate on read so bad hand-edits surface clearly
        cleaned = validate_inventory(data)
        return cleaned, file_hash
