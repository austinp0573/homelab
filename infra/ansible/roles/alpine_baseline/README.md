# alpine_baseline

Configures the steady-state baseline for Alpine hosts after first boot.

## scope

- installs baseline packages needed for management and day-to-day use
- manages hostname, timezone, users, SSH keys, and doas
- configures a small ash-friendly shell profile
- configures Dropbear as the Alpine SSH server
- adds a daily `apk upgrade` script through `crond`

Cloud-init should only bootstrap enough for Ansible to connect. This role owns the durable configuration afterward.

## defaults

- `alpine_baseline_packages`: includes Python, Dropbear, doas, certificates, and the OpenSSH client package for SCP compatibility.
- `alpine_baseline_users`: empty by default; define real users in inventory or encrypted vars.
- `alpine_baseline_doas_rules`: keeps the Ansible management user passwordless and gives wheel users persistent doas.
- `alpine_baseline_dropbear_options`: defaults to `-s`, which disables password logins.

## notes

This role is Alpine-only for now. It is structured so a later distro-specific split is straightforward, but the current implementation intentionally follows Alpine/OpenRC behavior.
