#!/usr/bin/env python3
import os
from pathlib import Path


NUT_DIR = Path("/etc/nut")
FILE_MODE = 0o775
DIR_MODE = 0o750


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"[config-init] Missing required environment variable: {name}")
    return value


def optional_env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def optional_ups_overrides() -> str:
    overrides = []
    battery_date = optional_env("UPS_BATTERY_DATE")
    battery_mfr_date = optional_env("UPS_BATTERY_MFR_DATE")
    if battery_date:
        overrides.append(f'\toverride.battery.date = "{battery_date}"')
    if battery_mfr_date:
        overrides.append(f'\toverride.battery.mfr.date = "{battery_mfr_date}"')
    return "\n".join(overrides)


def write_config(path: Path, content: str, uid: int, gid: int) -> None:
    path.write_text(content, encoding="utf-8")
    os.chmod(path, FILE_MODE)
    try:
        os.chown(path, uid, gid)
    except PermissionError:
        print(f"[config-init] Warning: could not chown {path}")


def main() -> None:
    uid = int(env("NUTIFY_CONFIG_UID", "1000"))
    gid = int(env("NUTIFY_CONFIG_GID", "1000"))

    ups_name = env("UPS_NAME")
    mon_user = env("NUT_MON_USER")
    mon_password = env("NUT_MON_PASSWORD")
    primary_user = env("NUT_PRIMARY_USER", "primarymon")
    primary_password = env("NUT_PRIMARY_PASSWORD", mon_password)
    admin_user = env("NUT_ADMIN_USER", "admin")
    admin_password = env("NUT_ADMIN_PASSWORD")

    NUT_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(NUT_DIR, DIR_MODE)
    try:
        os.chown(NUT_DIR, uid, gid)
    except PermissionError:
        print(f"[config-init] Warning: could not chown {NUT_DIR}")

    write_config(
        NUT_DIR / "nut.conf",
        """# Network UPS Tools configuration
# Managed by ups-stack config-init.py

MODE=netserver
""",
        uid,
        gid,
    )

    write_config(
        NUT_DIR / "ups.conf",
        f"""# Network UPS Tools: ups.conf
# Managed by ups-stack config-init.py

[{ups_name}]
\tdriver = "{env("UPS_DRIVER")}"
\tport = "{env("UPS_PORT", "auto")}"
\tvendorid = "{env("UPS_VENDOR_ID")}"
\tproductid = "{env("UPS_PRODUCT_ID")}"
\tproduct = "{env("UPS_PRODUCT_STRING")}"
\tserial = "{env("UPS_SERIAL")}"
\tvendor = "{env("UPS_VENDOR_NAME")}"
{optional_ups_overrides()}
{optional_env("UPS_EXTRA_CONFIG", "")}
# WARNING: bus, device, and busport are intentionally omitted.
# Those values can change when USB devices reconnect.
""",
        uid,
        gid,
    )

    write_config(
        NUT_DIR / "upsd.conf",
        """# Network UPS Tools: upsd.conf
# Managed by ups-stack config-init.py

LISTEN 0.0.0.0 3493
MAXCONN 16
""",
        uid,
        gid,
    )

    write_config(
        NUT_DIR / "upsd.users",
        f"""# Network UPS Tools: upsd.users
# Managed by ups-stack config-init.py

[{admin_user}]
    password = "{admin_password}"
    actions = SET
    instcmds = ALL

[{primary_user}]
    password = "{primary_password}"
    upsmon {ups_name} = master

[{mon_user}]
    password = "{mon_password}"
    upsmon {ups_name} = slave
""",
        uid,
        gid,
    )

    write_config(
        NUT_DIR / "upsmon.conf",
        f"""# Network UPS Tools: upsmon.conf
# Managed by ups-stack config-init.py

MONITOR {ups_name}@localhost 1 {primary_user} {primary_password} master

MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h now"
NOTIFYCMD /app/nutify/core/events/ups_notifier.py
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower

RBWARNTIME 43200
NOCOMMWARNTIME 300
FINALDELAY 5

NOTIFYFLAG ONLINE SYSLOG+WALL+EXEC
NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC
NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC
NOTIFYFLAG FSD SYSLOG+WALL+EXEC
NOTIFYFLAG COMMOK SYSLOG+WALL+EXEC
NOTIFYFLAG COMMBAD SYSLOG+WALL+EXEC
NOTIFYFLAG SHUTDOWN SYSLOG+WALL+EXEC
NOTIFYFLAG REPLBATT SYSLOG+WALL+EXEC
NOTIFYFLAG NOCOMM SYSLOG+WALL+EXEC
NOTIFYFLAG NOPARENT SYSLOG+WALL+EXEC

DEBUG_MIN 2
RUN_AS_USER nut
""",
        uid,
        gid,
    )

    print(f"[config-init] Rendered NUT config for UPS '{ups_name}'")


if __name__ == "__main__":
    main()
