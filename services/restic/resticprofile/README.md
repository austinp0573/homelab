# resticprofile compose template

## summary

template for running resticprofile inside docker compose. handles backing up to multiple targets (truenas rest server, cloudflare r2, garage s3, sftp, local disk) concurrently or sequentially using profile inheritance and groups.

replaces manual bash wrappers and single repo compose templates.

## layout

```text
resticprofile/
├── compose.yml
├── profiles.yml
├── includes.txt
├── excludes.txt
├── .env.example
├── .gitignore
├── docs/
│   ├── endpoints.md
│   └── configuration_guide.md
├── secrets/
│   ├── ssh/
│   │   ├── config.example
│   │   ├── id_ed25519.example
│   │   └── known_hosts.example
│   ├── password.txt.example
│   └── rest_secrets.env.example
├── certs/
├── scripts/
└── staging/
```

## setup

```bash
chmod 700 secrets
chmod 700 secrets/ssh
chmod 700 staging
chmod 700 cache

chmod 600 .env

find secrets -maxdepth 1 -type f -exec chmod 600 {} \;
find secrets/ssh -maxdepth 1 -type f -exec chmod 600 {} \;

chmod 700 scripts/*.sh

umask 077
```

5. edit profiles.yml to set repository URLs and customize active or commented configuration options.

## **containerd configuration**

Without properly configuring **containerd** `run --rm` leaves a **containerd**-shim behind.

**FIX:**

Create the `/etc/containerd/config.toml` and change `SystemdCgroup = true`

```bash
73-          cni_conf_dir = ''
74-          cni_max_conf_num = 0
75-          snapshotter = ''
76-          sandboxer = 'podsandbox'
77-          io_type = ''
78-
79-          [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
80-            BinaryName = ''
81-            CriuImagePath = ''
82-            CriuWorkPath = ''
83-            IoGid = 0
84-            IoUid = 0
85-            NoNewKeyring = false
86-            Root = ''
87-            ShimCgroup = ''
88:            SystemdCgroup = false # -> true
89-
90-    [plugins.'io.containerd.cri.v1.runtime'.cni]
91-      bin_dir = ''
92-      bin_dirs = ['/opt/cni/bin']
93-      conf_dir = '/etc/cni/net.d'
94-      max_conf_num = 1
95-      setup_serially = false
96-      conf_template = ''
97-      ip_pref = ''
98-      use_internal_loopback = false
99-
100-  [plugins.'io.containerd.differ.v1.erofs']
101-    mkfs_options = []
102-    enable_tar_index = false
103-    enable_dmverity = false
```

## usage

initialize repository endpoint:
docker compose run --rm resticprofile --name host-truenas init

run host backup to truenas:
docker compose run --rm resticprofile --name host-truenas backup

run host backup to all endpoints via group:
docker compose run --rm resticprofile --name host-all backup

run application backup to all endpoints:
docker compose run --rm resticprofile --name app-all backup

run sqlite database backup to all endpoints:
docker compose run --rm resticprofile --name sqlite-all backup

list snapshots on an endpoint:
docker compose run --rm resticprofile --name host-truenas snapshots

prune old snapshots on all endpoints:
docker compose run --rm resticprofile --name host-all forget

## troubleshooting & common issues

1. **repository resolves to `sftp::/` or empty paths**:
   - cause: using shell default fallback syntax like `${SFTP_HOST_ALIAS:-vps-05}` in `profiles.yml`.
   - solution: `resticprofile` uses standard Go environment variable expansion. use `${SFTP_HOST_ALIAS}` directly without `:-` fallbacks, and ensure `SFTP_HOST_ALIAS` is defined in `.env`.

2. **`cannot load profile: not found` or `parent profile 'default' not found`**:
   - cause: in config version 1 (`version: "1"`), profiles must be root-level keys starting at column 0.
   - solution: ensure profiles (`default:`, `host-base:`, `app-sftp:`) are not indented under `global:` and do not use a `profiles:` parent section wrapper.

3. **`failed loading groups: expected type 'string', got 'map'`**:
   - cause: formatting groups with a `profiles:` sub-key in config version 1.
   - solution: format groups as simple string lists directly under the group name:
     ```yaml
     groups:
       app-all:
         - app-sftp
         - app-local
     ```

4. **`Fatal: all source directories/files do not exist`**:
   - cause: `STAGING_DIR` in `.env` set to a relative host path like `./staging/kuma-backup/`.
   - solution: set `STAGING_DIR=/staging/kuma-backup` using an absolute path starting with `/staging/` which matches the container mount.

5. **`Fatal: unable to save snapshot: open /cache/tmp/...: no such file or directory`**:
   - cause: `TMPDIR` set to a non-existent `/cache/tmp` subfolder.
   - solution: set `TMPDIR: /cache` in `compose.yml` so restic writes temporary pack files directly into the mounted cache directory.

6. **compression level shows `auto` instead of `max`**:
   - cause: defining compression inside `option:` mapping.
   - solution: set `compression: "max"` and `pack-size: 64` as top-level profile properties on `default:`.

## documentation

* [https://restic.readthedocs.io/en/latest/index.html](https://restic.readthedocs.io/en/latest/index.html)
* [https://creativeprojects.github.io/resticprofile/index.html](https://creativeprojects.github.io/resticprofile/index.html)

## notes

- config version 1 format is used for 100% production stability.
- insecure tls is enabled for truenas rest target via global-flags in profiles.yml.
- compression is set to max and pack size to 64mb under default profile options.
- secrets are read securely from /run/secrets/ mounts inside the container.
- ssh config for sftp is mounted at /root/.ssh from ./secrets/ssh.
- sqlite and app staging scripts run before backups via profiles.yml hooks.
