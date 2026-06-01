# base

Applies the older Debian-family base configuration.

## scope

- installs common apt packages
- installs the official Ookla speedtest package
- deploys root shell aliases
- installs figlet fonts
- configures a fastfetch-based login MOTD

## notes

This role is intentionally documented as Debian-family only. It uses apt, systemd/journald-oriented aliases, bash profile behavior, and Debian-style MOTD paths. Alpine hosts should use `alpine_baseline` and `alpine_low_resource` instead.
