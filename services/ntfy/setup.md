# ntfy setup

provision vps on tierhive:

- `128MB` RAM
- `1GB` Disk
- Lowest: 
    - CPU
    - Disk I/O
- Highest: 
    - Networking
- OS: `Alpine 3.23.4`

## Initial setup

- SSH in 
- SCP scripts.tar.xz -> vps:/root/
- run ./setup.sh
    - (include unattended upgrades)
- reboot

## ntfy setup

```sh
apk add ntfy sqlite3
mkdir -p /var/cache/ntfy/attachments /var/lib/ntfy
chown -R ntfy:ntfy /var/cache/ntfy /var/lib/ntfy
chmod 700 /var/cache/ntfy /var/lib/ntfy
```

**back on your workstation**

- make your config
    - at [docs.ntfy.sh/config](https://docs.ntfy.sh/config/#__tabbed_3_2)
    - **MAKE SURE** `listen-http: "8080`, can't run on root ports (below 1024)

- `scp` that to the server

```bash
scp server.yml vps:/etc/ntfy/server.yml`
```

**back on the vps**

- ensure proper permissions:

```sh
chown root:ntfy /etc/ntfy/server.yml
chmod 640 /etc/ntfy/server.yml

chown root:ntfy /etc/ntfy
chmod 750 /etc/ntfy
```

- enable and start

```sh
rc-update add ntfy default
rc-service ntfy start
rc-service ntfy status
```

# notes

- query the database for all topics:

```sh
sqlite3 /var/cache/ntfy/cache.db "SELECT DISTINCT topic FROM messages ORDER BY topic;"
```