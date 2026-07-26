# restic env

covers `compose/` (backup client) + `gen-restic/` (UI that generates zip trees). leave `compose/overview-env.md` as the older prose copy. never put repo passwords or access tokens in `.env`.

## compose — always injected

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| image | `restic/restic:0.19.1` | Pinned client image for reproducible backup behavior. Floating tags change prune/check defaults under you. Bump deliberately after reading restic release notes. Same pin across hosts keeps `copy`/`mount` sane. |
| `container_name` | `restic` | Fixed name for `compose run` one-shots and logs. Collision if another project also named `restic`. One-shot jobs still benefit from a stable name in `ps`. Not a long-lived daemon here. |
| `RESTIC_REPOSITORY_FILE` | `/run/secrets/repo_location.txt` | Always injected — restic reads repo URL/path from this file. Prefer over `RESTIC_REPOSITORY` so secrets stay out of process listings. Missing/empty file fails every command immediately. Mount must be readable inside the container. |
| `RESTIC_PASSWORD_FILE` | `/run/secrets/password.txt` | Always injected repo password file. Prefer over `RESTIC_PASSWORD` / command. Wrong password looks like “repository does not exist” to tired eyes. Mode on the host secret file matters. |
| `RESTIC_CACHE_DIR` | `/cache` | Cache lives in-container at `/cache`, host often `/var/cache/restic`. Deleting cache slows next runs but is safe. Put on fast local disk, not the backup NAS. Full disk here stalls backups mysteriously. |
| `TMPDIR` | `/cache/tmp` | Temp space for pack assembly; keep on same volume as cache. Tiny `/tmp` in the image is a footgun — that is why this is set. Cleanup failures fill the volume. Ensure the path exists in the image/entrypoint. |
| `RESTIC_HOST` | *(required)* | Stable snapshot hostname tag. Changing it fragments `forget` policies by host. Use a logical name, not a DHCP hostname that flips. Required by lab scripts — empty breaks tagging assumptions. |
| `RESTIC_PACK_SIZE` | `64` | Pack size in MiB. Larger packs = fewer objects, harder small-delta; smaller = more API chatter on S3/R2. 64 is a sane lab default. Changing mid-repo is ok but alters future pack layout only. |
| `RESTIC_COMPRESSION` | `auto` | One of `off`/`fastest`/`auto`/`better`/`max`. `max` burns CPU for modest gains on already-compressed data. `off` for constrained CPUs or pre-compressed trees. Apply per-run; history keeps old compression. |
| `HOST_ROOT` | `/` (host) or `./empty-host` (app) | Bind source mounted `:ro` at `/host`. Host mode needs real `/`; app mode uses empty stub so you do not accidentally back up the host. Wrong mode backs up the wrong tree. Keep ro — never rw the live root. |
| `restart` | `no` | One-shot via `compose run` — should not restart as a daemon. `always` would loop failed backups. Cron/systemd owns scheduling, not compose restart policy. Leave `no`. |

## compose — profile / scripts

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `BACKUP_MODE` | `host` or `app` | Required by `backup.sh`. Host backs up `/host`; app backs up staged `/app/<name>`. Mixing modes in one dir without changing mounts confuses operators. Pick one deploy dir per job. |
| `APP_SOURCE_DIR` | `/srv/example-app` | Host path `stage-files.sh` rsyncs from in app mode. Wrong path stages empty trees that “succeed”. Needs host `rsync`. Not used in pure host mode. |
| `BACKUP_NAME` | `example-app` | Path segment under `/app/<name>`; `[A-Za-z0-9._-]` only. Drives staging dest and snapshot paths. Colliding names across apps overwrite staging. Keep stable for forget policies that key on paths. |
| `COMPOSE_CMD` | `nerdctl compose` | Wrapper scripts use this string. Override to `docker compose` on docker-only hosts. Mixing engines on the same project is undefined pain. Keep consistent with how the stack was first upped. |
| `HEALTHCHECKS_URL` | *(empty)* | Success pings URL; failure often `URL/fail` per script. Empty disables. Do not log full URLs if they embed tokens. Misconfigured HC creates false “backup failed” pages. |
| `NTFY_URL` | `https://ntfy.sh` | ntfy server base for failure notices. Point at your self-hosted ntfy when ready. Trailing slash quirks depend on script concat — keep clean. Unused if topic empty. |
| `NTFY_TOPIC` | *(empty)* | Set to enable failure ntfy. Empty = no notify even if URL/token set. Topic ACL must allow the token. Typo’d topic silently notifies nobody you watch. |
| `NTFY_TOKEN_FILE` | `./secrets/ntfy_token.txt` | Loads bearer into runtime. Prefer file over env. Missing file with restricted topic = 401s. Mode 600 on host. |
| `NTFY_TOKEN` | `<secret>` | Runtime token from file loader — do not commit. Overrides/ besides file depending on script order. Treat as `<secret>`. Rotate with ntfy ACL. |
| `REST_USERNAME_FILE` | `./secrets/rest_username.txt` | rest-server basic auth username file. Required for REST repos with auth. Empty username with password set fails oddly. Prefer files over inline env. |
| `REST_PASSWORD_FILE` | `./secrets/rest_password.txt` | rest-server password; `<secret>` in file. Must match server htpasswd/auth. Wrong creds look like network failures. Keep out of `.env`. |
| `RESTIC_REST_USERNAME` / `PASSWORD` | empty / `<secret>` | Inline alternatives — prefer file loaders. Password is `<secret>`. Easy to leak via `compose config`. Use only for break-glass. |
| `RESTIC_CACERT` | e.g. `/certs/truenas-ca.crt` | PEM for private CA (TrueNAS REST TLS). **Do not set for R2+TrueNAS dual jobs** — breaks R2 TLS (vw helper clears it on R2). Mount the PEM read-only. Wrong CA = x509 errors only on private endpoints. |
| `RESTIC_TLS_CLIENT_CERT` | *(empty)* | mTLS client cert+key path when rest-server requires it. Empty for normal labs. Mis-set breaks all TLS repos. Keep key modes tight. |
| `RESTIC_INSECURE_TLS` | *(empty)* | Leave blank. Setting truthy disables verify — only for broken labs. Never leave on for R2/public CAs. Prefer fixing CA trust instead. |
| `RESTIC_KEY_HINT` | *(empty)* | Speeds key finding in multi-key repos. Wrong hint just slows init paths. Optional polish. Safe to leave empty. |
| `RESTIC_READ_CONCURRENCY` | *(empty)* | Lower on busy/spinning disks to reduce seek storms. Empty = restic default. Too high on HDDs tanks latency for other services. Tune when backup windows fight VMs. |
| `RESTIC_PROGRESS_FPS` | *(empty)* | Progress redraw rate; empty = default. Lower for quieter logs on cron. Does not affect correctness. Useful over SSH TTYs. |
| `RESTIC_NO_CACHE` | *(empty)* | Disables cache when set; every run re-downloads indexes. Use for debugging corrupt cache. Slower and chatty on S3/R2. Leave empty normally. |
| `RESTIC_REPOSITORY` / `PASSWORD` / `PASSWORD_COMMAND` | avoid / `<secret>` | Prefer `*_FILE` variants. Password/`PASSWORD_COMMAND` leak via process tree more easily. Command must be available inside the container. Avoid in cron env files. |
| `BACKUP_LOCK_FILE` | `/var/lock/restic-backup.lock` | `backup.sh` flock path so overlapping cron does not dual-write. Stale lock after kill -9 needs manual removal. Put on local fs. Wrong path on shared storage deadlocks multiple hosts — use per-host locks. |
| `SQLITE_DB` | *(sqlite jobs)* | Path for `stage-sqlite.sh` only. Live DB copy via sqlite backup API semantics in the script. Wrong path stages nothing. Not used for host-file mode. |
| `STAGE_DEST` | `./staging/app/<name>` | Must sit under compose `/app` mount. Staging outside the mount = container cannot see files. Clean staging between runs if scripts do not. Disk full here fails before restic starts. |

## restic copy

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `RESTIC_FROM_REPOSITORY` / `_FILE` | *(empty)* | Source repo for `restic copy`. Prefer `_FILE`. Source and dest passwords differ often — set both. Empty source breaks copy immediately. |
| `RESTIC_FROM_PASSWORD` / `_FILE` / `_COMMAND` | `<secret>` / empty | Source auth — prefer files. Mixing dest password into FROM vars copies nowhere useful. Command form must work in-container. Source and dest passwords are independent — copying FROM_* into RESTIC_PASSWORD_* is a common mixup. |
| `RESTIC_FROM_KEY_HINT` | *(empty)* | Optional key hint for the source repo. Same semantics as `RESTIC_KEY_HINT`. Leave empty unless multi-key source. Only helps multi-key source repos; wrong hint just adds latency on open. |

## S3 / R2 / cloud

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `AWS_SHARED_CREDENTIALS_FILE` | `/run/secrets/aws_credentials` | Prefer over inline keys. INI profile file mounted read-only. Works for R2/S3-compatible. Missing file with S3 repo = auth errors. |
| `AWS_PROFILE` | *(empty)* | Profile name inside the credentials file. Empty often means `default`. Wrong profile silently uses other keys. Keep aligned with the file you mounted. |
| `AWS_DEFAULT_REGION` | *(empty)* / `auto` for R2 | R2 wants `auto` (or a placeholder) more than a real AWS region. Wrong region rarely matters for R2 but confuses AWS S3. Set explicitly in dual-cloud scripts. Lab R2 jobs should set this explicitly so dual TrueNAS/R2 scripts do not inherit a stale region. |
| `AWS_ACCESS_KEY_ID` / `SECRET` / `SESSION_TOKEN` | `<secret>` | Inline keys — prefer credentials file. Session token for temporary creds only. Easy to leak in `.env`. Rotate on any paste accident. |
| `RESTIC_AWS_ASSUME_ROLE_*` | *(empty)* | ARN, session name, external ID, policy, region, STS endpoint family. Only for assume-role setups. Misconfigured STS endpoint breaks all S3 ops. Leave empty for R2 static keys. |
| `AZURE_ACCOUNT_NAME` | *(empty)* | Azure Blob account for azure: repos. Must match the repo URL account. Empty unless you use Azure. Typo fails auth. |
| `AZURE_ACCOUNT_KEY` / `SAS` | `<secret>` | Key or SAS — keep out of `.env` when possible. SAS expiry is a silent break waiting to happen. Prefer least privilege SAS. Account keys are blast-radius huge compared to a scoped SAS — rotate on any paste into shell history and prefer file mounts when the scripts allow it. |
| `AZURE_ENDPOINT_SUFFIX` | *(empty)* | Sovereign/cloud suffix overrides. Wrong suffix points at the wrong cloud. Leave empty for public Azure. Needed for Azure China/Gov endpoints; public cloud should stay empty. |
| `AZURE_FORCE_CLI_CREDENTIAL` | *(empty)* | Force Azure CLI credential chain. Rarely needed in containers without `az` login. Leave empty unless you know you need it. Containers without an `az` login identity will just fail auth if this is forced on. |
| `B2_ACCOUNT_ID` | *(empty)* | Backblaze B2 key id. Required for b2: repos. Not the bucket name. Pair with `B2_ACCOUNT_KEY`. |
| `B2_ACCOUNT_KEY` | `<secret>` | B2 application key secret. Restrict to bucket. Leak = full bucket access. Prefer file injection if scripts support it. |
| `GOOGLE_PROJECT_ID` | *(empty)* | GCP project for GCS. Must match the bucket’s project. Empty unless GCS. Must match the project that owns the GCS bucket in the repo URL. |
| `GOOGLE_APPLICATION_CREDENTIALS` | *(empty)* | Path to service account JSON — mount the file. Env pointing at missing mount fails. Prefer workload identity outside labs when possible. Mount the JSON read-only and point this env at the in-container path, not the host path. |
| `GOOGLE_ACCESS_TOKEN` | `<secret>` | Short-lived token alternative. Expiry breaks long backups. Prefer JSON key file for cron. Fine for interactive restores; terrible for unattended cron once the token expires mid-run. |
| OpenStack `OS_*` / `ST_*` | *(empty)* | Swift/OpenStack envs; password/token/key/app-cred = `<secret>`. Easy to mis-set region/auth URL. Only for swift: repos. Auth URL + region mismatches are the usual silent 401 loop for swift repos. |
| `RCLONE_BWLIMIT` | *(empty)* | e.g. `10M` when restic/rclone path rate-limits. Protects WAN links during daytime. Empty = unlimited. Does not replace restic’s own packing costs. |

## secret files

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `repo_location.txt` | repo URL | Repo URL/path; treat as `<secret>` in real deploys (may embed creds/hosts). Mounted at `RESTIC_REPOSITORY_FILE`. Typo wastes hours. One file per job/dir. |
| `password.txt` | `<secret>` | Repo password. Losing it loses the repo. Keep offline copies. Mode 600. |
| `rest_username.txt` / `rest_password.txt` | `<secret>` | rest-server basic auth pair. Must match server. Password file is `<secret>`. Unused for pure S3/R2. |
| `ntfy_token.txt` | `<secret>` | Optional bearer for restricted topics. Empty/missing disables auth headers. Rotate with ntfy. Only needed when the topic ACL requires a bearer; public topics can leave this absent. |
| `aws_credentials` | `<secret>` | R2/S3 INI credentials. Prefer over env. Wrong profile/region still fails. Do not commit. |
| `truenas_repo_location.txt` | *(vw-backup)* | Second repo location for copy/DR. Used by vw helpers alongside primary. Keep distinct from R2 location. Pair with the matching rest-server password files when that second repo is REST-authenticated. |

## vw-backup helpers

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `VW_DATA_DIR` | `/opt/vaultwarden-…/vaultwarden-data` | Live Vaultwarden data directory on the host. Wrong path backs up empty/wrong state. Stop/consistent SQLite staging still matters. Attachments live here too — unlike Litestream. |
| `STAGE_DEST` | `./staging/vaultwarden-data` | Must match compose `/staging` mount. Staging outside mount = invisible to restic container. Clean after success if scripts leave debris. Disk pressure here aborts before upload. |
| (reuses) | host, compose cmd, AWS/R2, rest auth, ntfy, HC | Same knobs as compose scripts. `BACKUP_MODE` unused by `backup-vw.sh`. Do not set conflicting `RESTIC_CACERT` for dual R2+TrueNAS without the helper clear. Staging still has to land under the compose `/staging` mount or the restic one-shot backs up an empty tree that looks like a successful VW backup. |

## gen-restic UI

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `gen-restic` | Local image `${name}:local` ties to this project name. Changing breaks image tag expectations in scripts. Keep unique on the host. Scripts that build `${COMPOSE_PROJECT_NAME}:local` will miss the image if this drifts. |
| `CONTAINER_NAME` | `gen-restic` | UI container name. Loopback publish only in sane setups. Logs for generation failures land here. Keep distinct from the backup `restic` one-shot container name on the same engine. |
| `RESTART_POLICY` | `unless-stopped` | UI is long-lived unlike backup one-shots. Stop intentionally if you do not want it after reboot. Not on the backup critical path. Unlike backup jobs, leaving this UI stopped across reboot is usually fine. |
| `HOST_BIND` | `127.0.0.1` | Keep local; do not expose a zip-generator UI widely. Tailnet access via SSH tunnel or proxy. Changing to `0.0.0.0` needs firewall intent. The UI emits deploy trees with secrets placeholders — treat a LAN-exposed bind as leaking backup layout and env shape, not just a convenience port. |
| `HOST_PORT` | `8788` | → container `:80`. Bookmarks and smoke tests use this. Conflict with other labs on 8788 — change left side only. Proxy or SSH-tunnel to this port; do not publish the generator widely on a shared LAN. |
| `COMPOSE_CMD` | auto nerdctl/docker | Scripts probe for available engine. Force if detection picks wrong. Keep consistent with image build path. Mismatch between build and up engines leaves you running a stale local tag. |

UI defaults mirror the compose `.env` keys when generating trees. prune helper defaults in UI: `keep_daily=7`, `keep_weekly=4`, `keep_monthly=12`, `keep_yearly=2`, `check_args=--read-data-subset=5%`. gen-restic does **not** emit `backup.sh` — copy helpers from the compose template.

host vs app are alternatives (one deploy dir = one job). app profile needs host `rsync` + `sqlite3`.
