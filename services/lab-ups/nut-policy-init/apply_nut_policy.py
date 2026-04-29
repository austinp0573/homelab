#!/usr/bin/env python3
import os
import re
from pathlib import Path


NUT_DIR = Path("/etc/nut")


def optional_env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def read(path: Path) -> str:
    if not path.exists():
        raise SystemExit(
            f"{path} does not exist yet. Finish Nutify Web UI setup first, "
            "then run: docker compose up nut-policy-init"
        )
    return path.read_text(encoding="utf-8")


def write(path: Path, content: str, mode: int = 0o640) -> None:
    path.write_text(content, encoding="utf-8")
    os.chmod(path, mode)
    uid = int(optional_env("NUT_CONFIG_UID", "1000"))
    gid = int(optional_env("NUT_CONFIG_GID", "1000"))
    # chown may fail if this container isn't running as root, which is fine —
    # the file permissions from chmod are still applied.
    try:
        os.chown(path, uid, gid)
    except PermissionError:
        print(f"[nut-policy-init] Warning: could not chown {path}")


def infer_ups_name(ups_conf: str) -> str:
    # UPS_NAME may not be set yet on a truly fresh deployment, so fall back to
    # reading the first [section] header from ups.conf. That's safe for single-UPS
    # setups and avoids a chicken-and-egg on first run.
    configured = optional_env("UPS_NAME")
    if configured:
        return configured
    match = re.search(r"(?m)^\[([^\]]+)\]\s*$", ups_conf)
    if not match:
        raise SystemExit("Could not infer UPS_NAME from ups.conf; set UPS_NAME in .env")
    return match.group(1)


def set_directive_in_section(content: str, section: str, key: str, value: str, quote: bool = True) -> str:
    header_re = re.compile(rf"(?m)^\[{re.escape(section)}\]\s*$")
    header = header_re.search(content)
    if not header:
        raise SystemExit(f"Could not find [{section}] in ups.conf")

    # Bound the section body by looking for the next [header]. Without this we'd
    # risk matching a directive with the same name in a different section.
    next_header = re.search(r"(?m)^\[[^\]]+\]\s*$", content[header.end() :])
    section_end = len(content) if not next_header else header.end() + next_header.start()
    before = content[: header.end()]
    body = content[header.end() : section_end]
    after = content[section_end:]

    directive_re = re.compile(rf"(?m)^(\s*){re.escape(key)}\s*=.*$")
    rendered_value = f'"{value}"' if quote else value
    replacement = f"\t{key} = {rendered_value}"
    if directive_re.search(body):
        body = directive_re.sub(replacement, body)
    else:
        if not body.endswith("\n"):
            body += "\n"
        body += replacement + "\n"
    return before + body + after


def set_flag_in_section(content: str, section: str, key: str, enabled: bool) -> str:
    header_re = re.compile(rf"(?m)^\[{re.escape(section)}\]\s*$")
    header = header_re.search(content)
    if not header:
        raise SystemExit(f"Could not find [{section}] in ups.conf")

    next_header = re.search(r"(?m)^\[[^\]]+\]\s*$", content[header.end() :])
    section_end = len(content) if not next_header else header.end() + next_header.start()
    before = content[: header.end()]
    body = content[header.end() : section_end]
    after = content[section_end:]

    # NUT flags like allow_killpower have no value — they're bare keywords.
    # Remove any existing instance first (including any accidental "key = ..." form)
    # then re-add if enabled. Cleaner than trying to toggle in-place.
    flag_re = re.compile(rf"(?m)^\s*{re.escape(key)}\s*(?:=.*)?$")
    body = flag_re.sub("", body)
    body = re.sub(r"\n{3,}", "\n\n", body)
    if enabled:
        if not body.endswith("\n"):
            body += "\n"
        body += f"\t{key}\n"
    return before + body + after


def apply_ups_conf_policy() -> str:
    path = NUT_DIR / "ups.conf"
    content = read(path)
    ups_name = infer_ups_name(content)

    # override.* keys and string metadata go in quotes per NUT config syntax.
    policy_values = {
        "override.battery.charge.low": optional_env("NUT_LOW_BATTERY_THRESHOLD"),
        "override.battery.date": optional_env("UPS_BATTERY_DATE"),
        "override.battery.mfr.date": optional_env("UPS_BATTERY_MFR_DATE"),
    }
    for key, value in policy_values.items():
        if value:
            content = set_directive_in_section(content, ups_name, key, value)

    # Driver timing parameters are bare integers, not quoted strings.
    driver_values = {
        "offdelay": optional_env("NUT_UPS_OFF_DELAY"),
        "ondelay": optional_env("NUT_UPS_ON_DELAY"),
    }
    for key, value in driver_values.items():
        if value:
            content = set_directive_in_section(content, ups_name, key, value, quote=False)

    allow_killpower = optional_env("NUT_ALLOW_KILLPOWER").lower()
    if allow_killpower in ("1", "true", "yes", "on"):
        content = set_flag_in_section(content, ups_name, "allow_killpower", True)
    elif allow_killpower in ("0", "false", "no", "off"):
        content = set_flag_in_section(content, ups_name, "allow_killpower", False)

    extra = optional_env("UPS_EXTRA_CONFIG")
    if extra and extra not in content:
        content = content.rstrip() + "\n\n# Managed by power-control: extra NUT config\n" + extra.rstrip() + "\n"

    write(path, content)
    return ups_name


def upsert_upsd_user_section(
    content: str, username: str, password: str, extra_lines: list[str], comment: str
) -> str:
    section_lines = [f"[{username}]", f'    password = "{password}"'] + extra_lines
    section = "\n".join(section_lines) + "\n"
    # (?ms) makes . match newlines and ^ match line starts; the lookahead stops
    # the match at the next section header so we don't eat neighboring users.
    section_re = re.compile(
        rf"(?ms)^\[{re.escape(username)}\]\s*\n.*?(?=^\[[^\]]+\]\s*$|\Z)"
    )
    if section_re.search(content):
        return section_re.sub(section, content).rstrip() + "\n"
    return content.rstrip() + f"\n\n# Managed by power-control: {comment}\n" + section


def apply_upsd_users_policy(ups_name: str) -> None:
    username = optional_env("NUT_CLIENT_USER")
    password = optional_env("NUT_CLIENT_PASSWORD")
    # Both blank is a valid "skip this" signal. One without the other is a config mistake.
    if not username and not password:
        return
    if not username or not password:
        raise SystemExit("Set both NUT_CLIENT_USER and NUT_CLIENT_PASSWORD, or leave both blank")

    role = optional_env("NUT_CLIENT_ROLE", "slave").lower()
    if role not in ("master", "slave"):
        raise SystemExit("NUT_CLIENT_ROLE must be master or slave")

    path = NUT_DIR / "upsd.users"
    content = read(path)
    content = upsert_upsd_user_section(
        content, username, password, [f"    upsmon {role}"], "remote NUT client user"
    )
    write(path, content)
    print(f"[nut-policy-init] Upserted NUT client user '{username}' as {role}")


def apply_fsd_user_policy() -> None:
    username = optional_env("NUT_FSD_USER")
    password = optional_env("NUT_FSD_PASSWORD")
    if not username or not password:
        print("[nut-policy-init] NUT_FSD_USER/NUT_FSD_PASSWORD not set; skipping FSD user injection")
        return

    path = NUT_DIR / "upsd.users"
    content = read(path)
    # actions = FSD lets restore-watcher send the FSD command directly to upsd.
    # instcmds = driver.killpower lets it send driver.killpower via upscmd after the
    # shutdown delay, which is what actually tells the UPS to cut output power.
    # Both are needed because they're separate permission gates in upsd.
    content = upsert_upsd_user_section(
        content,
        username,
        password,
        ["    upsmon slave", "    actions = FSD", "    instcmds = driver.killpower"],
        "restore-watcher FSD trigger and killpower user",
    )
    write(path, content)
    print(f"[nut-policy-init] Upserted NUT FSD user '{username}'")


def cleanup_upsmon_managed_blocks() -> None:
    """Strip any directives previously injected into upsmon.conf by older versions of this stack.

    Nutify regenerates upsmon.conf from its database on every restart, so any manual
    edits get wiped anyway. We stopped patching it, but need to clean up what earlier
    runs left behind so Nutify doesn't choke on duplicate or stale directives.
    """
    path = NUT_DIR / "upsmon.conf"
    if not path.exists():
        return
    content = path.read_text(encoding="utf-8")
    original = content

    filtered = []
    for line in content.splitlines():
        stripped = line.strip()
        if stripped == "# Managed by power-control: send these NUT events through upssched.":
            continue
        if stripped == "NOTIFYCMD /usr/sbin/upssched":
            continue
        filtered.append(line)

    content = "\n".join(filtered)
    content = re.sub(r"\n{3,}", "\n\n", content)
    if not content.endswith("\n"):
        content += "\n"

    if content != original:
        write(path, content)
        print("[nut-policy-init] Cleaned up previous upsmon.conf managed blocks")
    else:
        print("[nut-policy-init] upsmon.conf already clean; nothing to remove")


def main() -> None:
    ups_name = apply_ups_conf_policy()
    apply_upsd_users_policy(ups_name)
    apply_fsd_user_policy()
    cleanup_upsmon_managed_blocks()
    print(f"[nut-policy-init] Applied NUT policy for UPS '{ups_name}'")


if __name__ == "__main__":
    main()
