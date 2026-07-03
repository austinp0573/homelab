# backup script

this directory contains a generic backup script template for self hosted app data

the script stages the data directory, handles sqlite files with sqlite backup, compresses the archive with zstd, optionally encrypts it, then sends it to cloudflare r2 or a local directory

install the needed tools on the target host before running the script

```sh
apk add --no-cache findutils tar zstd sqlite age curl rclone coreutils
```

- copy `.env.example` to `.env`
- set `DATA_DIR` to the app data directory
- set `APP_NAME` to a short name for the app
- set `BACKUP_DEST_TYPE` to `r2` or `local`
- set `RCLONE_REMOTE` when using r2
- set `LOCAL_DEST_DIR` when using local
- set `COMPRESSION_TYPE` to `zstd`
- set `ZSTD_FLAGS` to the zstd flags to use
- set `ENCRYPT_BACKUP` to `yes` or `no`
- set `ENCRYPTION_TYPE` to `age` when encryption is enabled
- set `AGE_PUBLIC_KEY` when encryption is enabled
- set `HEALTHCHECKS_URL` only if you want healthchecks pings
- set `REMOTE_RETENTION_ENABLED` to `yes` only when the r2 token can delete objects
- set `RETENTION_DAYS` when remote retention is enabled
- set `EXCLUDE_PATTERNS` for runtime data you do not want in the backup
- set `LOCK_ENABLED` to `yes` or `no`
- set `LOCK_DIR` only if you want a custom lock path
- keep `.env` local and do not deploy it to the target machine

render the script with an explicit envsubst variable list

```sh
set -a
. ./.env
set +a

envsubst '${DATA_DIR} ${APP_NAME} ${BACKUP_DEST_TYPE} ${RCLONE_REMOTE} ${LOCAL_DEST_DIR} ${COMPRESSION_TYPE} ${ENCRYPT_BACKUP} ${ENCRYPTION_TYPE} ${AGE_PUBLIC_KEY} ${HEALTHCHECKS_URL} ${REMOTE_RETENTION_ENABLED} ${RETENTION_DAYS} ${EXCLUDE_PATTERNS} ${LOCK_DIR} ${ZSTD_FLAGS} ${LOCK_ENABLED}' < backup.sh.tmpl > backup.sh

envsubst '${RCLONE_NAME} ${RCLONE_TYPE} ${RCLONE_PROVIDER} ${RCLONE_ACCESS_KEY_ID} ${RCLONE_SECRET_ACCESS_KEY} ${RCLONE_ENDPOINT} ${RCLONE_NO_CHECK_BUCKET}' < rclone.conf.tmpl > rclone.conf

chmod 700 backup.sh
```

copy the rendered script to the target host

```sh
scp backup.sh root@example-host:/opt/scripts/backup.sh
```

for r2 backups, configure rclone on the target host before running the script

- alpine rclone docs, https://wiki.alpinelinux.org/wiki/Rclone
- cloudflare r2 rclone docs, https://developers.cloudflare.com/r2/examples/rclone/

```sh
rclone config
# n for new remote
n
# remote name
r2
# amazon s3 compatible storage
4
# cloudflare r2 storage
7
# enter credentials manually
2
# access key id
your_access_key_id
# secret access key
your_secret_access_key
# region auto
1
# endpoint from the r2 dashboard
https://account_id.r2.cloudflarestorage.com
# advanced config
n
```

if the r2 token only has object read and write, add this to the rclone remote

```ini
no_check_bucket = true
```

example rclone remote

```ini
[r2]
type = s3
provider = Cloudflare
access_key_id = your_access_key_id
secret_access_key = your_secret_access_key
endpoint = https://account_id.r2.cloudflarestorage.com
no_check_bucket = true
```

```sh
scp rclone.conf root@example-host:/root/.config/rclone/rclone.conf
```

example cron entry

```sh
0 3 * * * /bin/sh /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
```

restore a backup

- stop the service before restoring
- copy the archive to the restore host
- if encrypted, decrypt it with the age private key
- extract it into a temporary restore directory
- inspect the files before replacing live data
- replace the app data directory with the restored files
- fix ownership and permissions if the service needs a specific user
- start the service
- check the app and logs before deleting the old data

### restore

acquire compose file from:

- https://github.com/austinp0573/homelab/tree/main/services/vaultwarden/standalone-vaultwarden

1. retrieve backup

- from the cloudflare gui

or

- using `rclone`

```bash
rclone copy name:bucket_name/directory/sub-directory/most_recent_backup.tar.zst.age /tmp/
```

2. decrypt

```bash
age --decrypt --identity /home/name/key_file.txt --output /tmp/most_recent_backup.tar.zst /tmp/most_recent_backup.tar.zst.age
```

3. decompress

```bash
zstd --decompress /tmp/most_recent_backup.tar.zst --output /tmp/most_recent_backup.tar
```

4. extract to vaultwarden-data directory

```bash
tar -xf /tmp/most_recent_backup.tar -C /opt/vaultwarden-deployment-directory/vaultwarden-data-directory/
```

5. start the container

```bash
# nerdctl, docker, podman
docker compose up -d
```

6. go to it

- Open the browser
- Navigate to the bind port
- put in the `user-email`
- put in the `user-password`

restore an encrypted backup

```sh
age -d -i age-private-key.txt backup.tar.zst.age > backup.tar.zst
mkdir -p restore
zstd -d -c backup.tar.zst | tar -C restore -xf -
```

restore an unencrypted backup

```sh
mkdir -p restore
zstd -d -c backup.tar.zst | tar -C restore -xf -
```

notes

- sqlite wal shm and journal sidecar files are skipped when the base database is backed up
- healthchecks is optional and an empty url disables pings
- local backups are not pruned by this script
- r2 backups are pruned only when `REMOTE_RETENTION_ENABLED` is `yes`
- overlapping runs are avoided with a lock directory when `LOCK_ENABLED` is `yes`
- the script does not install packages during a backup run
- object read and write r2 tokens need `no_check_bucket = true`
