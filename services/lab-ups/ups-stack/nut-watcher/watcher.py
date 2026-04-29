#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import docker
import requests


FLAG_DIR = Path("/var/run/nut-flags")
SHUTDOWN_FLAG = FLAG_DIR / "shutdown-requested.json"
ON_BATTERY_FLAG = FLAG_DIR / "on-battery-since"


def log(message: str) -> None:
    print(f"[nut-watcher] {message}", flush=True)


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def env_int(name: str, default: int | None = None) -> int:
    raw = env(name, None if default is None else str(default))
    try:
        return int(raw)
    except ValueError as exc:
        raise SystemExit(f"{name} must be an integer, got {raw!r}") from exc


def env_float_optional(name: str) -> float | None:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return None
    try:
        return float(raw)
    except ValueError as exc:
        raise SystemExit(f"{name} must be a number, got {raw!r}") from exc


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


def split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def wake_targets_from_hosts_json(value: str) -> tuple[list[str], list[str]]:
    if not value.strip():
        return [], []
    try:
        hosts = json.loads(value)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"UPSNAP_HOSTS_JSON is not valid JSON: {exc}") from exc
    if not isinstance(hosts, list):
        raise SystemExit("UPSNAP_HOSTS_JSON must be a JSON array")

    ids: list[str] = []
    macs: list[str] = []
    for index, host in enumerate(hosts, start=1):
        if not isinstance(host, dict):
            raise SystemExit(f"UPSNAP_HOSTS_JSON item {index} must be an object")
        if host.get("wake_after_restore", True) is False:
            continue
        device_id = host.get("upsnap_id") or host.get("id")
        if device_id:
            ids.append(str(device_id))
        if host.get("mac"):
            macs.append(str(host["mac"]).lower())

    return list(dict.fromkeys(ids)), list(dict.fromkeys(macs))


@dataclass
class UpsState:
    status: str
    battery_charge: float

    @property
    def on_battery(self) -> bool:
        tokens = set(self.status.upper().split())
        return "OB" in tokens

    @property
    def online(self) -> bool:
        tokens = set(self.status.upper().split())
        return "OL" in tokens


class NutClient:
    def __init__(self) -> None:
        self.host = env("NUT_HOST", "nutify")
        self.port = env_int("NUT_PORT", 3493)
        self.ups_name = env("UPS_NAME")
        self.username = os.environ.get("NUT_MON_USER", "")
        self.password = os.environ.get("NUT_MON_PASSWORD", "")

    def _request(self, command: str) -> str:
        with socket.create_connection((self.host, self.port), timeout=10) as sock:
            reader = sock.makefile("r", encoding="utf-8", newline="\n")
            writer = sock.makefile("w", encoding="utf-8", newline="\n")

            if self.username and self.password:
                self._send(writer, f"USERNAME {self.username}")
                self._expect_ok(reader, "USERNAME")
                self._send(writer, f"PASSWORD {self.password}")
                self._expect_ok(reader, "PASSWORD")

            self._send(writer, command)
            response = reader.readline().strip()
            self._send(writer, "LOGOUT")
            return response

    @staticmethod
    def _send(writer: Any, command: str) -> None:
        writer.write(f"{command}\n")
        writer.flush()

    @staticmethod
    def _expect_ok(reader: Any, command: str) -> None:
        response = reader.readline().strip()
        if response != "OK":
            raise RuntimeError(f"NUT {command} failed: {response}")

    def get_var(self, variable: str) -> str:
        response = self._request(f"GET VAR {self.ups_name} {variable}")
        prefix = f'VAR {self.ups_name} {variable} "'
        if not response.startswith(prefix) or not response.endswith('"'):
            raise RuntimeError(f"Unexpected NUT response for {variable}: {response}")
        return response[len(prefix) : -1]

    def state(self) -> UpsState:
        return UpsState(
            status=self.get_var("ups.status"),
            battery_charge=float(self.get_var("battery.charge")),
        )


class FsdTrigger:
    def __init__(self) -> None:
        self.container_name = env("NUTIFY_CONTAINER_NAME", "nutify")
        self.dry_run = env_bool("FSD_DRY_RUN", False)

    def trigger(self) -> None:
        if self.dry_run:
            log("FSD_DRY_RUN=true, skipping upsmon -c fsd")
            return

        client = docker.from_env()
        container = client.containers.get(self.container_name)
        for command in (["/usr/sbin/upsmon", "-c", "fsd"], ["/usr/bin/upsmon", "-c", "fsd"], ["upsmon", "-c", "fsd"]):
            result = container.exec_run(command)
            output = result.output.decode("utf-8", errors="replace").strip()
            if result.exit_code == 0:
                log(f"Triggered FSD with: {' '.join(command)}")
                return
            log(f"FSD command failed ({' '.join(command)}): exit={result.exit_code} output={output}")

        raise RuntimeError("All upsmon -c fsd attempts failed")


class HostShutdown:
    def __init__(self) -> None:
        self.enabled = env_bool("HOST_SHUTDOWN_ENABLED", True)
        self.delay = env_int("HOST_SHUTDOWN_DELAY", 120)
        self.command = split_csv(
            os.environ.get(
                "HOST_SHUTDOWN_COMMAND",
                "nsenter,-t,1,-m,-u,-i,-n,-p,--,/sbin/shutdown,-h,now",
            )
        )

    def trigger(self) -> None:
        if not self.enabled:
            log("HOST_SHUTDOWN_ENABLED=false, leaving host shutdown to NUT/Nutify")
            return
        if not self.command:
            raise RuntimeError("HOST_SHUTDOWN_COMMAND produced an empty command")

        log(f"Triggering host shutdown with: {' '.join(self.command)}")
        subprocess.run(self.command, check=True)


class UpSnapClient:
    def __init__(self) -> None:
        self.base_url = env("UPSNAP_URL").rstrip("/")
        self.email = env("UPSNAP_ADMIN_EMAIL")
        self.password = env("UPSNAP_ADMIN_PASSWORD")
        self.session = requests.Session()
        self.session.timeout = 20
        self.token: str | None = None

    def authenticate(self) -> None:
        endpoints = (
            "/api/collections/_superusers/auth-with-password",
            "/api/admins/auth-with-password",
            "/api/collections/users/auth-with-password",
        )
        payload = {"identity": self.email, "password": self.password}
        for endpoint in endpoints:
            try:
                response = self.session.post(f"{self.base_url}{endpoint}", json=payload, timeout=20)
            except requests.RequestException as exc:
                log(f"UpSnap auth endpoint {endpoint} failed: {exc}")
                continue
            if response.ok and response.json().get("token"):
                self.token = response.json()["token"]
                self.session.headers.update({"Authorization": f"Bearer {self.token}"})
                log(f"Authenticated to UpSnap via {endpoint}")
                return
            log(f"UpSnap auth endpoint {endpoint} returned HTTP {response.status_code}")
        raise RuntimeError("Unable to authenticate to UpSnap")

    def list_devices(self) -> list[dict[str, Any]]:
        if self.token is None:
            self.authenticate()
        response = self.session.get(f"{self.base_url}/api/collections/devices/records?perPage=500", timeout=20)
        response.raise_for_status()
        data = response.json()
        return data.get("items", [])

    def resolve_device_ids(self, ids: list[str], macs: list[str]) -> list[str]:
        resolved = list(dict.fromkeys(ids))
        if not macs:
            return resolved

        normalized = {mac.lower(): mac for mac in macs}
        for device in self.list_devices():
            values = [
                str(device.get(key, "")).lower()
                for key in ("mac", "mac_address", "macAddress", "mac_address_1")
            ]
            if any(value in normalized for value in values):
                device_id = device.get("id")
                if device_id:
                    resolved.append(str(device_id))

        return list(dict.fromkeys(resolved))

    def wake(self, device_id: str) -> None:
        if self.token is None:
            self.authenticate()
        response = self.session.get(f"{self.base_url}/api/upsnap/wake/{device_id}", timeout=20)
        response.raise_for_status()
        log(f"Requested wake for UpSnap device {device_id}")


class Watcher:
    def __init__(self) -> None:
        FLAG_DIR.mkdir(parents=True, exist_ok=True)
        self.nut = NutClient()
        self.fsd = FsdTrigger()
        self.host_shutdown = HostShutdown()
        self.shutdown_battery_threshold = env_int("SHUTDOWN_BATTERY_THRESHOLD")
        self.shutdown_time_on_battery = env_int("SHUTDOWN_TIME_ON_BATTERY")
        self.wakeup_battery_threshold = env_int("WAKEUP_BATTERY_THRESHOLD")
        self.poll_interval = env_int("POLL_INTERVAL", 30)
        host_ids, host_macs = wake_targets_from_hosts_json(os.environ.get("UPSNAP_HOSTS_JSON", ""))
        explicit_ids = split_csv(os.environ.get("UPSNAP_DEVICE_IDS", ""))
        explicit_macs = [mac.lower() for mac in split_csv(os.environ.get("WAKE_MAC_ADDRESSES", ""))]
        self.upsnap_ids = list(dict.fromkeys(explicit_ids + host_ids))
        self.wake_macs = list(dict.fromkeys(explicit_macs + host_macs))
        self.force_on_battery = env_bool("FORCE_ON_BATTERY", False)
        self.force_battery_charge = env_float_optional("FORCE_BATTERY_CHARGE")
        if (self.force_on_battery or self.force_battery_charge is not None) and not self.fsd.dry_run:
            raise SystemExit("FORCE_ON_BATTERY/FORCE_BATTERY_CHARGE require FSD_DRY_RUN=true")

    def run(self) -> None:
        if SHUTDOWN_FLAG.exists():
            self.wake_after_restore()
        self.monitor()

    def monitor(self) -> None:
        log("Starting threshold monitor")
        while True:
            try:
                state = self.apply_test_overrides(self.nut.state())
                self.handle_state(state)
            except Exception as exc:
                log(f"Monitor error: {exc}")
            time.sleep(self.poll_interval)

    def apply_test_overrides(self, state: UpsState) -> UpsState:
        if not self.force_on_battery and self.force_battery_charge is None:
            return state

        forced_state = UpsState(
            status="OB" if self.force_on_battery else state.status,
            battery_charge=self.force_battery_charge
            if self.force_battery_charge is not None
            else state.battery_charge,
        )
        log(
            "Applying dry-run test overrides: "
            f"status={forced_state.status} battery={forced_state.battery_charge:.1f}%"
        )
        return forced_state

    def handle_state(self, state: UpsState) -> None:
        log(f"UPS status={state.status} battery={state.battery_charge:.1f}%")
        if state.on_battery:
            on_battery_since = self.ensure_on_battery_since()
            elapsed = int(time.time() - on_battery_since)
            if state.battery_charge <= self.shutdown_battery_threshold:
                self.request_shutdown("battery-threshold", state, elapsed)
            elif elapsed >= self.shutdown_time_on_battery:
                self.request_shutdown("time-on-battery", state, elapsed)
            return

        if state.online:
            if SHUTDOWN_FLAG.exists():
                log("AC power restored after shutdown request; running restore wake check")
                if state.battery_charge >= self.wakeup_battery_threshold:
                    self.wake_targets()
                    SHUTDOWN_FLAG.unlink(missing_ok=True)
                    ON_BATTERY_FLAG.unlink(missing_ok=True)
                    log("Wake sequence complete; cleared shutdown flag")
                else:
                    log("Battery is below wake threshold; keeping shutdown flag")
                return
            if ON_BATTERY_FLAG.exists():
                ON_BATTERY_FLAG.unlink()
                log("AC power restored before shutdown threshold")
            return

        log("UPS is neither clearly online nor on battery; no action taken")

    def ensure_on_battery_since(self) -> float:
        if ON_BATTERY_FLAG.exists():
            return float(ON_BATTERY_FLAG.read_text(encoding="utf-8").strip())
        timestamp = time.time()
        ON_BATTERY_FLAG.write_text(str(timestamp), encoding="utf-8")
        log("Detected AC loss, starting on-battery timer")
        return timestamp

    def request_shutdown(self, reason: str, state: UpsState, elapsed: int) -> None:
        if SHUTDOWN_FLAG.exists():
            log("Shutdown flag already exists; FSD was already requested")
            return

        payload = {
            "reason": reason,
            "ups_status": state.status,
            "battery_charge": state.battery_charge,
            "seconds_on_battery": elapsed,
            "requested_at": int(time.time()),
        }
        SHUTDOWN_FLAG.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        log(f"Shutdown threshold reached: {payload}")
        self.fsd.trigger()
        if self.host_shutdown.enabled and self.host_shutdown.delay > 0:
            log(f"Waiting {self.host_shutdown.delay}s before host shutdown")
            time.sleep(self.host_shutdown.delay)
            latest_state = self.nut.state()
            if latest_state.online:
                log("AC power restored during host shutdown delay; skipping host shutdown")
                return
        self.host_shutdown.trigger()

    def wake_after_restore(self) -> None:
        log("Shutdown flag found; waiting for restored power and wake battery threshold")
        while True:
            try:
                state = self.nut.state()
                log(f"Restore check status={state.status} battery={state.battery_charge:.1f}%")
                if state.online and state.battery_charge >= self.wakeup_battery_threshold:
                    self.wake_targets()
                    SHUTDOWN_FLAG.unlink(missing_ok=True)
                    ON_BATTERY_FLAG.unlink(missing_ok=True)
                    log("Wake sequence complete; cleared shutdown flag")
                    return
            except Exception as exc:
                log(f"Restore wait error: {exc}")
            time.sleep(self.poll_interval)

    def wake_targets(self) -> None:
        client = UpSnapClient()
        device_ids = client.resolve_device_ids(self.upsnap_ids, self.wake_macs)
        if not device_ids:
            log("No UpSnap device IDs resolved; skipping wake calls")
            return

        for device_id in device_ids:
            try:
                client.wake(device_id)
            except Exception as exc:
                log(f"Failed to wake UpSnap device {device_id}: {exc}")


if __name__ == "__main__":
    Watcher().run()
