# vaultwarden -> restic (R2 + TrueNAS)

replace the old age/rclone vaultwarden backup on vm-01 with the restic compose stack.

deploy path on the host: `/opt/restic-vw-backup/`
live data: `/opt/vaultwarden-cloudflared/vaultwarden-data`

flow:
1. stage a consistent copy of vw data (sqlite hot copy, skip icon_cache)
2. restic backup that staging dir to Cloudflare R2
3. restic copy those snapshots to TrueNAS rest-server
4. ping healthchecks only if both 2 and 3 succeeded
5. send optional ntfy failure messages

---

## retention / storage

R2 is the offsite copy that is hard to wipe.

- turn on R2 Object Lock for 365 days on the bucket
- daily R2 API token should not be able to delete objects (put/get/list only)
- do not run forget/prune against R2 from this host
- do not add an R2 lifecycle rule that deletes objects by age. that will break the restic repo. object lock is not the same thing as "auto delete after N days"

restic dedups, so you are not storing a full new dump every night. for vaultwarden the repo stays small even if R2 keeps locked packs around for a year. growth is mostly changed bytes + snapshot metadata, not "full backup x 365".

TrueNAS is the curated copy:
- append-only rest-server from the client
- after copy, prune on the nas with 7 daily / 4 weekly / 12 monthly (see below)
- same restic password as R2 so `copy` is simple

---

## one-time: R2

1. create a new R2 bucket. name is whatever you want; it goes in `secrets/repo_location.txt`.
2. enable Object Lock, 365 day retention on new objects.
3. create an API token that can read/write/list this bucket, but not delete.
4. note the S3 API endpoint (`https://<accountid>.r2.cloudflarestorage.com`).

---

## one-time: TrueNAS

1. make sure rest-server is up (see `../../truenas/truenas-setup.md`). append-only on.
2. pick a repo path under the restic dataset, e.g. `vm-01-vaultwarden`.
3. copy the TrueNAS TLS cert to the client as `certs/truenas-ca.crt` if you use https.
4. have rest basic-auth user/pass ready.

---

## one-time: deploy on vm-01

```sh
# on your workstation, from the repo
rsync -a --exclude vw-backup services/restic/compose/ root@vm-01:/opt/restic-vw-backup/

# also copy the vw helpers
scp services/restic/compose/vw-backup/stage-vw.sh \
    services/restic/compose/vw-backup/backup-vw.sh \
    root@vm-01:/opt/restic-vw-backup/
```

on vm-01:

```sh
cd /opt/restic-vw-backup
chmod 700 stage-vw.sh backup-vw.sh
cp .env.example.app .env
mkdir -p /var/cache/restic/tmp staging secrets certs

# alpine packages used by staging / healthchecks
apk add --no-cache sqlite rsync curl
```

edit `.env`:

```sh
RESTIC_HOST=vm-01-vaultwarden
COMPOSE_CMD=nerdctl compose

# s3 / R2
AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws_credentials
AWS_DEFAULT_REGION=auto

# rest server auth files (TrueNAS copy). leave the paths even for R2-only init.
REST_USERNAME_FILE=./secrets/rest_username.txt
REST_PASSWORD_FILE=./secrets/rest_password.txt

# do not set RESTIC_CACERT in .env. restic uses that CA for ALL tls
# (including R2). backup-vw.sh passes the TrueNAS ca only on copy.

RESTIC_PACK_SIZE=64
RESTIC_COMPRESSION=auto

# used by stage-vw.sh / backup-vw.sh
VW_DATA_DIR=/opt/vaultwarden-cloudflared/vaultwarden-data
STAGE_DEST=./staging/vaultwarden-data
HEALTHCHECKS_URL=https://hc-ping.com/your-uuid-here
NTFY_URL=https://ntfy.sh
NTFY_TOPIC=
NTFY_TOKEN_FILE=./secrets/ntfy_token.txt
```

`backup-vw.sh` calls `stage-vw.sh` itself. The generic `BACKUP_MODE` and app
source settings in the profile are unused by this job.

secrets:

```sh
# repo password - same value for R2 and TrueNAS
cp secrets/password.txt.example secrets/password.txt
# put a long random password in secrets/password.txt

# R2 repo locator (bucket name is yours)
printf '%s\n' 's3:https://<accountid>.r2.cloudflarestorage.com/<bucket-name>' \
  > secrets/repo_location.txt

# TrueNAS repo locator
printf '%s\n' 'rest:https://<truenas-ip>:8000/vm-01-vaultwarden' \
  > secrets/truenas_repo_location.txt

# rest auth
printf '%s\n' 'rest-user' > secrets/rest_username.txt
printf '%s\n' 'rest-pass' > secrets/rest_password.txt

# R2 keys (no delete on this token)
cp secrets/aws_credentials.example secrets/aws_credentials
# fill aws_access_key_id / aws_secret_access_key
```

```sh
chmod 600 .env secrets/*
```

drop the TrueNAS public cert in place, then build a bundle that still trusts public CAs
(needed because `restic copy` talks to R2 and TrueNAS in one process, and RESTIC_CACERT
replaces the default trust store):

```sh
# on vm-01 (alpine: ca-certificates package)
apk add --no-cache ca-certificates
cp /path/to/truenas.crt /opt/restic-vw-backup/certs/truenas-ca.crt
cat /etc/ssl/certs/ca-certificates.crt   /opt/restic-vw-backup/certs/truenas-ca.crt   > /opt/restic-vw-backup/certs/ca-bundle.crt
```

stock `backup.sh` backs up host `/`. do not cron that on this box for vw. use `backup-vw.sh`.

---

## one-time: init both repos

```sh
cd /opt/restic-vw-backup

# R2 (default secrets/repo_location.txt)
./scripts/init-repo.sh

# TrueNAS - override repo file for this one run
set -a; . ./.env; set +a
export RESTIC_REST_USERNAME="$(tr -d '\r\n' < "$REST_USERNAME_FILE")"
export RESTIC_REST_PASSWORD="$(tr -d '\r\n' < "$REST_PASSWORD_FILE")"
nerdctl compose run --rm \
  -e RESTIC_REPOSITORY_FILE=/run/secrets/truenas_repo_location.txt \
  -e RESTIC_CACERT=/certs/ca-bundle.crt \
  restic init
```

---

## daily job

```sh
/opt/restic-vw-backup/backup-vw.sh
```

what it does:
- stages `VW_DATA_DIR` into `staging/vaultwarden-data` (skips icon_cache, hot-copies sqlite)
- `restic backup /staging/vaultwarden-data` to R2
- `restic copy` from R2 to TrueNAS
- curls `HEALTHCHECKS_URL` only if both worked; curls `HEALTHCHECKS_URL/fail` on failure
- sends an ntfy message on failure when `NTFY_TOPIC` is set

cron (same window you already use):

```sh
0 3 * * * root /opt/restic-vw-backup/backup-vw.sh >> /var/log/restic-vw-backup.log 2>&1
```

---

## TrueNAS prune

run on the nas (clients are append-only). same password file as the repo.

```sh
REPO_PATH=/mnt/coldpool/restic/admin/vm-01-vaultwarden \
PASSWORD_FILE=/root/restic-password.txt \
KEEP_DAILY=7 KEEP_WEEKLY=4 KEEP_MONTHLY=12 KEEP_YEARLY=0 \
 /path/to/homelab/services/restic/truenas/prune.sh
```

if `KEEP_YEARLY=0` complains on your restic version, drop that env and leave the script default.

schedule that on the nas however you like (weekly is fine).

---

## cutover from the old backup

1. finish R2 + TrueNAS init.
2. run `backup-vw.sh` by hand once. check logs.
3. list snapshots:

```sh
cd /opt/restic-vw-backup
set -a; . ./.env; set +a
nerdctl compose run --rm restic snapshots
```

4. restore test into a throwaway dir (VW stopped or a different path):

```sh
./scripts/restore.sh latest /tmp/vw-restore-test
# expect vaultwarden-data/... under that path depending on snapshot paths
ls -la /tmp/vw-restore-test
```

5. optional: point a temporary recovery compose at the restored data and unlock a vault once.
6. when you are satisfied, remove the old age/rclone cron entry. leave the old script on disk if you want; just do not run it.

---

## restore for real

1. stop vaultwarden on the target host.
2. restore latest (or a snapshot id) somewhere temporary.
3. replace `/opt/vaultwarden-cloudflared/vaultwarden-data` with the restored tree (keep a copy of the broken dir until you confirm).
4. start vaultwarden. log in. check attachments if you use them.

from R2 (default repo on this host):

```sh
./scripts/restore.sh latest /tmp/vw-restore
```

from TrueNAS, run the same restore helper after pointing `secrets/repo_location.txt` at the rest url temporarily, or:

```sh
set -a; . ./.env; set +a
export RESTIC_REST_USERNAME="$(tr -d '\r\n' < "$REST_USERNAME_FILE")"
export RESTIC_REST_PASSWORD="$(tr -d '\r\n' < "$REST_PASSWORD_FILE")"
mkdir -p /tmp/vw-restore
nerdctl compose run --rm \
  -e RESTIC_REPOSITORY_FILE=/run/secrets/truenas_repo_location.txt \
  -e RESTIC_CACERT=/certs/ca-bundle.crt \
  -v /tmp/vw-restore:/restore \
  restic restore latest --target /restore
```

---

## notes

- icon_cache is excluded on purpose. it rebuilds.
- do not forget/prune R2 from the backup key. that is intentional with object lock.
- if copy to TrueNAS fails, healthchecks gets a fail ping and R2 still has the new snapshot.
- bucket name is only in `secrets/repo_location.txt`. change it there when you create the bucket.
- put `truenas_repo_location.txt` under `secrets/` so it shows up in the container at `/run/secrets/`.
