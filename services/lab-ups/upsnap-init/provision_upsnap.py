#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.request


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def optional_env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def request(method: str, url: str, body: dict | None = None, token: str | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=15) as response:
        payload = response.read()
        if not payload:
            return {}
        return json.loads(payload.decode("utf-8"))


def wait_for_upsnap(base_url: str, timeout: int) -> None:
    deadline = time.monotonic() + timeout
    last_error = ""
    while time.monotonic() < deadline:
        try:
            request("GET", f"{base_url}/api/health")
            return
        except Exception as exc:
            last_error = str(exc)
            time.sleep(2)
    raise SystemExit(f"Timed out waiting for UpSnap at {base_url}: {last_error}")


def authenticate(base_url: str) -> str:
    email = env("UPSNAP_ADMIN_EMAIL")
    password = env("UPSNAP_ADMIN_PASSWORD")
    # UpSnap changed its PocketBase auth endpoint between v4 and v5.
    # Try all three so this works without version-specific config.
    endpoints = (
        "/api/collections/_superusers/auth-with-password",
        "/api/admins/auth-with-password",
        "/api/collections/users/auth-with-password",
    )
    for endpoint in endpoints:
        try:
            data = request("POST", f"{base_url}{endpoint}", {"identity": email, "password": password})
        except urllib.error.HTTPError:
            continue
        if data.get("token"):
            print(f"[upsnap-init] Authenticated via {endpoint}")
            return data["token"]
    raise SystemExit(
        "UpSnap admin login failed. Create the first UpSnap admin in the web UI, "
        "then set UPSNAP_ADMIN_EMAIL and UPSNAP_ADMIN_PASSWORD to that account."
    )


def load_hosts() -> list[dict]:
    raw = optional_env("UPSNAP_HOSTS_JSON")
    if not raw:
        print("[upsnap-init] UPSNAP_HOSTS_JSON is empty; nothing to provision")
        return []
    try:
        hosts = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"UPSNAP_HOSTS_JSON is not valid JSON: {exc}") from exc
    if not isinstance(hosts, list):
        raise SystemExit("UPSNAP_HOSTS_JSON must be a JSON array")
    return hosts


def list_devices(base_url: str, token: str) -> list[dict]:
    data = request("GET", f"{base_url}/api/collections/devices/records?perPage=200", token=token)
    return data.get("items", [])


def build_shutdown_command(host: dict) -> str:
    command = host.get("shutdown_command") or optional_env(
        "UPSNAP_DEFAULT_SHUTDOWN_COMMAND", "sudo /sbin/shutdown -h now"
    )
    ssh_user = host.get("ssh_user") or optional_env("UPSNAP_SSH_USER", "upsnap-shutdown")
    key_path = host.get("ssh_key_path") or optional_env("UPSNAP_SSH_KEY_PATH", "/app/ssh/id_ed25519")
    ssh_options = host.get("ssh_options") or optional_env(
        "UPSNAP_SSH_OPTIONS",
        "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/app/ssh/known_hosts",
    )
    # {{ DEVICE_IP }} is UpSnap's Go template placeholder — it gets substituted with the
    # device's IP address at runtime when UpSnap executes the shutdown command.
    return f"ssh -i {key_path} {ssh_options} '{ssh_user}@{{{{ DEVICE_IP }}}}' '{command}'"


def device_payload(host: dict) -> dict:
    name = host["name"]
    ip = host["ip"]
    mac = host["mac"]
    payload = {
        "name": name,
        "ip": ip,
        "mac": mac,
        "netmask": host.get("netmask", "255.255.255.0"),
        "description": host.get("description", ""),
        "shutdown_cmd": host.get("upsnap_shutdown_cmd") or build_shutdown_command(host),
        "shutdown_timeout": int(host.get("shutdown_timeout", optional_env("UPSNAP_DEFAULT_SHUTDOWN_TIMEOUT", "120"))),
    }
    for field in ("ping_cmd", "wake_cmd"):
        if host.get(field):
            payload[field] = host[field]
    return payload


def upsert_device(base_url: str, token: str, existing: list[dict], host: dict) -> None:
    payload = device_payload(host)
    # Match on MAC first (stable hardware identifier), fall back to name.
    # Either is enough to avoid creating duplicates when re-running provisioning.
    match = next(
        (
            device
            for device in existing
            if device.get("mac", "").lower() == payload["mac"].lower()
            or device.get("name") == payload["name"]
        ),
        None,
    )
    if match:
        request("PATCH", f"{base_url}/api/collections/devices/records/{match['id']}", payload, token)
        print(f"[upsnap-init] Updated {payload['name']} ({payload['mac']})")
    else:
        request("POST", f"{base_url}/api/collections/devices/records", payload, token)
        print(f"[upsnap-init] Created {payload['name']} ({payload['mac']})")


def main() -> None:
    if optional_env("UPSNAP_INIT_SKIP", "false").lower() in ("1", "true", "yes"):
        print("[upsnap-init] UPSNAP_INIT_SKIP=true; exiting")
        return

    base_url = env("UPSNAP_URL").rstrip("/")
    timeout = int(optional_env("UPSNAP_INIT_TIMEOUT", "120"))
    wait_for_upsnap(base_url, timeout)
    token = authenticate(base_url)
    hosts = load_hosts()
    existing = list_devices(base_url, token)
    for host in hosts:
        for required in ("name", "ip", "mac"):
            if not host.get(required):
                raise SystemExit(f"Host entry is missing required field: {required}")
        upsert_device(base_url, token, existing, host)
        # Re-fetch after each upsert so the next iteration's duplicate check sees
        # the record we just created, not a stale snapshot from before the loop.
        existing = list_devices(base_url, token)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP {exc.code}: {body}", file=sys.stderr)
        raise
