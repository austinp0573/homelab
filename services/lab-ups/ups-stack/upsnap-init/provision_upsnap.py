#!/usr/bin/env python3
import json
import os
import shlex
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


def log(message: str) -> None:
    print(f"[upsnap-init] {message}", flush=True)


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


def request_json(
    url: str,
    *,
    method: str = "GET",
    token: str | None = None,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed: HTTP {exc.code} {details}") from exc
    return {} if not raw else json.loads(raw)


def wait_for_upsnap(base_url: str) -> None:
    deadline = time.time() + int(os.environ.get("UPSNAP_INIT_TIMEOUT", "120"))
    while time.time() < deadline:
        try:
            request_json(f"{base_url}/api/health")
            return
        except Exception as exc:
            log(f"Waiting for UpSnap API: {exc}")
            time.sleep(3)
    raise RuntimeError("Timed out waiting for UpSnap API")


def authenticate(base_url: str) -> str:
    payload = {
        "identity": env("UPSNAP_ADMIN_EMAIL").strip(),
        "password": env("UPSNAP_ADMIN_PASSWORD").strip(),
    }
    endpoints = (
        "/api/collections/_superusers/auth-with-password",
        "/api/admins/auth-with-password",
        "/api/collections/users/auth-with-password",
    )
    for endpoint in endpoints:
        try:
            response = request_json(f"{base_url}{endpoint}", method="POST", payload=payload)
        except Exception as exc:
            log(f"Auth endpoint {endpoint} failed: {exc}")
            continue
        token = response.get("token")
        if token:
            log(f"Authenticated via {endpoint}")
            return str(token)
    raise RuntimeError("Unable to authenticate to UpSnap")


def load_hosts() -> list[dict[str, Any]]:
    raw = os.environ.get("UPSNAP_HOSTS_JSON", "").strip()
    if not raw:
        log("UPSNAP_HOSTS_JSON is empty; nothing to provision")
        return []
    try:
        hosts = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"UPSNAP_HOSTS_JSON is not valid JSON: {exc}") from exc
    if not isinstance(hosts, list):
        raise SystemExit("UPSNAP_HOSTS_JSON must be a JSON array")
    for index, host in enumerate(hosts, start=1):
        if not isinstance(host, dict):
            raise SystemExit(f"UPSNAP_HOSTS_JSON item {index} must be an object")
    return hosts


def list_devices(base_url: str, token: str) -> list[dict[str, Any]]:
    response = request_json(f"{base_url}/api/collections/devices/records?perPage=500", token=token)
    return list(response.get("items", []))


def build_shutdown_cmd(host: dict[str, Any]) -> str:
    if host.get("shutdown_cmd"):
        return str(host["shutdown_cmd"])

    ssh_user = str(host.get("shutdown_user") or os.environ.get("UPSNAP_SSH_USER", "upsnap-shutdown"))
    key_path = os.environ.get("UPSNAP_SSH_KEY_PATH", "/app/ssh/id_ed25519")
    remote_command = str(
        host.get("shutdown_command")
        or os.environ.get("UPSNAP_DEFAULT_SHUTDOWN_COMMAND", "sudo /usr/bin/systemctl poweroff")
    )
    options = os.environ.get(
        "UPSNAP_SSH_OPTIONS",
        "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/app/ssh/known_hosts",
    )
    target = f"{ssh_user}@{{{{ DEVICE_IP }}}}"
    return f"ssh -i {shlex.quote(key_path)} {options} {shlex.quote(target)} {shlex.quote(remote_command)}"


def device_payload(host: dict[str, Any]) -> dict[str, Any]:
    required = ("name", "ip", "mac")
    missing = [field for field in required if not host.get(field)]
    if missing:
        raise SystemExit(f"Host {host!r} is missing required fields: {', '.join(missing)}")

    shutdown_cron = str(host.get("shutdown_cron", ""))
    payload: dict[str, Any] = {
        "name": str(host["name"]),
        "ip": str(host["ip"]),
        "mac": str(host["mac"]),
        "netmask": str(host.get("netmask", "24")),
        "description": str(host.get("description", "")),
        "shutdown_cmd": build_shutdown_cmd(host),
        "shutdown_cron": shutdown_cron,
        "shutdown_cron_enabled": bool(host.get("shutdown_cron_enabled", bool(shutdown_cron))),
        "shutdown_timeout": int(host.get("shutdown_timeout", os.environ.get("UPSNAP_DEFAULT_SHUTDOWN_TIMEOUT", "120"))),
        "shutdown_confirm": bool(host.get("shutdown_confirm", False)),
        "wake_confirm": bool(host.get("wake_confirm", False)),
    }

    for optional in ("wake_cron", "wake_cron_enabled", "wake_timeout", "wake_cmd", "ping_cmd", "link", "link_open"):
        if optional in host:
            payload[optional] = host[optional]

    return payload


def find_existing(devices: list[dict[str, Any]], payload: dict[str, Any]) -> dict[str, Any] | None:
    wanted_mac = str(payload["mac"]).lower()
    wanted_name = str(payload["name"]).lower()
    for device in devices:
        if str(device.get("mac", "")).lower() == wanted_mac:
            return device
    for device in devices:
        if str(device.get("name", "")).lower() == wanted_name:
            return device
    return None


def upsert_devices(base_url: str, token: str, hosts: list[dict[str, Any]]) -> None:
    devices = list_devices(base_url, token)
    resolved_ids: list[str] = []

    for host in hosts:
        payload = device_payload(host)
        existing = find_existing(devices, payload)
        if existing:
            device_id = str(existing["id"])
            request_json(f"{base_url}/api/collections/devices/records/{device_id}", method="PATCH", token=token, payload=payload)
            log(f"Updated device {payload['name']} ({device_id})")
        else:
            created = request_json(f"{base_url}/api/collections/devices/records", method="POST", token=token, payload=payload)
            device_id = str(created["id"])
            log(f"Created device {payload['name']} ({device_id})")
        resolved_ids.append(device_id)

    if resolved_ids:
        log(f"Resolved UPSNAP_DEVICE_IDS={','.join(resolved_ids)}")


def main() -> int:
    if env_bool("UPSNAP_INIT_SKIP", False):
        log("UPSNAP_INIT_SKIP=true; skipping provisioning")
        return 0

    base_url = env("UPSNAP_URL").rstrip("/")
    hosts = load_hosts()
    if not hosts:
        return 0

    wait_for_upsnap(base_url)
    token = authenticate(base_url)
    upsert_devices(base_url, token, hosts)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        log(f"Provisioning failed: {exc}")
        raise SystemExit(1)
