#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


STATE_DIR = Path("/state")
OUTAGE_FLAG = STATE_DIR / "shutdown-expected.json"
UPS_NAME_CACHE: str | None = None


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def optional_env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def bool_status(status: str, flag: str) -> bool:
    return flag in status.split()


def read_ups() -> dict[str, str]:
    ups = resolve_ups_name()
    host = env("NUT_HOST", "nutify")
    port = env("NUT_PORT", "3493")
    # upsc reads are unauthenticated — credentials are only required for upscmd/upsrw
    result = subprocess.run(
        ["upsc", f"{ups}@{host}:{port}"],
        text=True,
        capture_output=True,
        check=True,
    )
    values = {}
    for line in result.stdout.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    return values


def resolve_ups_name() -> str:
    global UPS_NAME_CACHE
    configured = optional_env("UPS_NAME")
    if configured:
        return configured
    # Cache the discovered name so we're not issuing a `upsc -l` on every poll cycle.
    if UPS_NAME_CACHE:
        return UPS_NAME_CACHE

    host = env("NUT_HOST", "nutify")
    port = env("NUT_PORT", "3493")
    result = subprocess.run(
        ["upsc", "-l", f"{host}:{port}"],
        text=True,
        capture_output=True,
        check=True,
    )
    names = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if len(names) != 1:
        raise RuntimeError(f"Set UPS_NAME in .env; discovered UPS names: {', '.join(names) or 'none'}")
    UPS_NAME_CACHE = names[0]
    print(f"[restore-watcher] Inferred UPS_NAME={UPS_NAME_CACHE}")
    return UPS_NAME_CACHE


def battery_charge(values: dict[str, str]) -> int:
    raw = values.get("battery.charge")
    if raw is None:
        raise RuntimeError("NUT output did not include battery.charge")
    return int(float(raw))


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


def upsnap_token() -> str:
    base_url = env("UPSNAP_URL").rstrip("/")
    payload = {
        "identity": env("UPSNAP_ADMIN_EMAIL"),
        "password": env("UPSNAP_ADMIN_PASSWORD"),
    }
    # UpSnap changed its PocketBase auth endpoint between v4 and v5.
    # Try all three in order so this works across versions without config changes.
    endpoints = (
        "/api/collections/_superusers/auth-with-password",
        "/api/admins/auth-with-password",
        "/api/collections/users/auth-with-password",
    )
    for endpoint in endpoints:
        try:
            data = request("POST", f"{base_url}{endpoint}", payload)
        except urllib.error.HTTPError:
            continue
        if data.get("token"):
            return data["token"]
    raise RuntimeError("Unable to authenticate to UpSnap")


def list_devices(token: str) -> list[dict]:
    base_url = env("UPSNAP_URL").rstrip("/")
    data = request("GET", f"{base_url}/api/collections/devices/records?perPage=200", token=token)
    return data.get("items", [])


def desired_wake_targets(devices: list[dict]) -> list[dict]:
    ids = [item.strip() for item in optional_env("UPSNAP_DEVICE_IDS").split(",") if item.strip()]
    macs = [item.strip().lower() for item in optional_env("WAKE_MAC_ADDRESSES").split(",") if item.strip()]

    hosts_raw = optional_env("UPSNAP_HOSTS_JSON")
    if hosts_raw and not macs and not ids:
        hosts = json.loads(hosts_raw)
        macs = [host["mac"].lower() for host in hosts if host.get("mac")]

    if ids:
        return [device for device in devices if device.get("id") in ids]
    if macs:
        return [device for device in devices if device.get("mac", "").lower() in macs]
    return devices


def wake_device(token: str, device: dict) -> None:
    base_url = env("UPSNAP_URL").rstrip("/")
    device_id = device["id"]
    # Same version-compat strategy as upsnap_token — try known wake endpoints
    # across UpSnap versions until one accepts the request.
    endpoints = [
        ("GET", f"{base_url}/api/upsnap/wake/{device_id}"),
        ("POST", f"{base_url}/api/collections/devices/records/{device_id}/wake"),
        ("POST", f"{base_url}/api/devices/{device_id}/wake"),
    ]
    last_error = None
    for method, url in endpoints:
        try:
            request(method, url, {} if method == "POST" else None, token=token)
            print(f"[restore-watcher] Wake requested for {device.get('name', device_id)}")
            return
        except urllib.error.HTTPError as exc:
            last_error = f"HTTP {exc.code} from {url}: {exc.read().decode('utf-8', errors='replace')}"
    raise RuntimeError(last_error or f"Could not wake device {device_id}")


def mark_shutdown_expected(reason: str, values: dict[str, str], on_battery_for: int) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "reason": reason,
        "status": values.get("ups.status", ""),
        "battery_charge": values.get("battery.charge", ""),
        "on_battery_for": on_battery_for,
        "created_at": int(time.time()),
    }
    OUTAGE_FLAG.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"[restore-watcher] Marked shutdown expected: {reason}")


def clear_shutdown_expected() -> None:
    try:
        OUTAGE_FLAG.unlink()
    except FileNotFoundError:
        pass


def wake_after_restore() -> None:
    token = upsnap_token()
    devices = list_devices(token)
    targets = desired_wake_targets(devices)
    if not targets:
        print("[restore-watcher] No UpSnap devices matched wake targets")
        return
    for device in targets:
        wake_device(token, device)


def issue_killpower() -> None:
    """Send driver.killpower via upscmd so the UPS cuts output power after offdelay.

    In a normal NUT setup, `upsdrvctl -k` is called from an OS shutdown script or
    systemd unit. That never fires inside a Docker container. This is the replacement —
    called by restore-watcher after FSD has been active for KILLPOWER_DELAY seconds,
    which gives other hosts time to start shutting down before the UPS cuts power.

    Requires the NUT_FSD_USER to have `instcmds = driver.killpower` in upsd.users,
    which nut-policy-init injects.
    """
    ups_name = resolve_ups_name()
    host = env("NUT_HOST", "nutify")
    port = env("NUT_PORT", "3493")
    user = optional_env("NUT_FSD_USER")
    password = optional_env("NUT_FSD_PASSWORD")

    if not user or not password:
        print("[restore-watcher] NUT_FSD_USER/NUT_FSD_PASSWORD not set; skipping killpower")
        return

    result = subprocess.run(
        ["upscmd", "-u", user, "-p", password, f"{ups_name}@{host}:{port}", "driver.killpower"],
        text=True,
        capture_output=True,
    )
    if result.returncode == 0:
        print(f"[restore-watcher] killpower issued; UPS will cut output after offdelay")
    else:
        print(f"[restore-watcher] killpower failed (exit {result.returncode}): {result.stderr.strip()}")


def trigger_fsd() -> None:
    """Send the NUT FSD (Forced Shutdown) command directly to upsd via the NUT protocol.

    We talk to upsd over a raw TCP socket instead of shelling out to `upsmon -c fsd`
    because that requires a local upsmon instance. The raw protocol is simple: authenticate,
    LOGIN to register as a client, send `FSD <ups>`, then LOGOUT.

    upsd broadcasts the FSD flag to every connected upsmon client — Nutify's internal
    master and any host nut-monitor slaves — which triggers their SHUTDOWNCMD after FINALDELAY.

    Requires a user with `actions = FSD` in upsd.users, injected by nut-policy-init.
    """
    ups_name = resolve_ups_name()
    host = env("NUT_HOST", "nutify")
    port = int(env("NUT_PORT", "3493"))
    user = optional_env("NUT_FSD_USER")
    password = optional_env("NUT_FSD_PASSWORD")

    if not user or not password:
        print("[restore-watcher] NUT_FSD_USER/NUT_FSD_PASSWORD not set; FSD trigger skipped")
        return

    conn = socket.create_connection((host, port), timeout=10)
    buf = b""

    try:
        def readline() -> str:
            nonlocal buf
            while b"\n" not in buf:
                chunk = conn.recv(4096)
                if not chunk:
                    raise RuntimeError("Connection closed by upsd")
                buf += chunk
            line, buf = buf.split(b"\n", 1)
            return line.decode("utf-8", errors="replace").strip()

        def send_cmd(cmd: str) -> str:
            conn.sendall((cmd + "\n").encode())
            return readline()

        send_cmd(f"USERNAME {user}")
        send_cmd(f"PASSWORD {password}")
        send_cmd(f"LOGIN {ups_name}")
        result = send_cmd(f"FSD {ups_name}")
        send_cmd("LOGOUT")
    finally:
        conn.close()

    if result.startswith("OK"):
        print(f"[restore-watcher] FSD triggered successfully for {ups_name}")
    else:
        raise RuntimeError(f"FSD command returned unexpected response: {result!r}")


def main() -> None:
    poll_interval = int(env("POLL_INTERVAL", "30"))
    wake_threshold = int(env("RESTORE_WAKEUP_BATTERY_THRESHOLD", "60"))
    mark_battery_threshold = int(env("RESTORE_MARK_BATTERY_THRESHOLD", "20"))
    mark_seconds = int(env("RESTORE_MARK_ON_BATTERY_SECONDS", "1800"))
    killpower_delay = int(optional_env("KILLPOWER_DELAY", "60"))
    on_battery_since: float | None = None
    fsd_detected_at: float | None = None
    killpower_issued = False

    print("[restore-watcher] Starting restore-watcher (polls NUT, triggers FSD, wakes hosts on AC restore)")
    while True:
        try:
            values = read_ups()
            status = values.get("ups.status", "")
            charge = battery_charge(values)
            on_battery = bool_status(status, "OB")
            online = bool_status(status, "OL")
            fsd_active = bool_status(status, "FSD")

            if on_battery and on_battery_since is None:
                on_battery_since = time.monotonic()
                print("[restore-watcher] UPS is on battery")
            elif not on_battery:
                on_battery_since = None

            on_battery_for = 0 if on_battery_since is None else int(time.monotonic() - on_battery_since)

            # Write the flag as soon as FSD is active regardless of who triggered it.
            # If Nutify's own upsmon fires FSD before restore-watcher does, we still
            # need the flag so the wake-after-restore logic runs on AC return.
            if fsd_active and not OUTAGE_FLAG.exists():
                mark_shutdown_expected("fsd_detected", values, on_battery_for)

            # Record when FSD first appeared so we can enforce the killpower delay.
            if fsd_active and fsd_detected_at is None:
                fsd_detected_at = time.monotonic()
                print(f"[restore-watcher] FSD active; will issue killpower in {killpower_delay}s")

            if not fsd_active:
                fsd_detected_at = None
                killpower_issued = False

            # Wait KILLPOWER_DELAY seconds after FSD before issuing killpower. This gives
            # other NUT clients (short FINALDELAY) time to start shutting down before the
            # UPS cuts power. Must fire before the NanoPi's own FINALDELAY expires.
            if (
                fsd_active
                and fsd_detected_at is not None
                and not killpower_issued
                and (time.monotonic() - fsd_detected_at) >= killpower_delay
            ):
                issue_killpower()
                killpower_issued = True

            if on_battery and not OUTAGE_FLAG.exists():
                if charge <= mark_battery_threshold:
                    mark_shutdown_expected("battery_threshold", values, on_battery_for)
                    trigger_fsd()
                elif on_battery_for >= mark_seconds:
                    mark_shutdown_expected("time_on_battery", values, on_battery_for)
                    trigger_fsd()

            if online and OUTAGE_FLAG.exists():
                if charge >= wake_threshold:
                    print(f"[restore-watcher] AC restored and battery is {charge}%; waking hosts")
                    wake_after_restore()
                    clear_shutdown_expected()
                else:
                    print(
                        f"[restore-watcher] AC restored, waiting for battery {charge}% "
                        f"to reach {wake_threshold}%"
                    )
        except Exception as exc:
            print(f"[restore-watcher] {exc}", file=sys.stderr)

        time.sleep(poll_interval)


if __name__ == "__main__":
    main()
