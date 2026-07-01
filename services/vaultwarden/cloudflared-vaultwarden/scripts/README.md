# backup script

this directory contains a generic encrypted backup script template for self hosted app data

the script stages the data directory, handles sqlite files with sqlite backup, encrypts the archive with age, then sends it to cloudflare r2 or a local directory

- copy `.env.example` to `.env`
- set `DATA_DIR` to the app data directory
- set `APP_NAME` to a short name for the app
- set `BACKUP_DEST_TYPE` to `r2` or `local`
- set `AGE_PUBLIC_KEY` to the age recipient public key
- set `HEALTHCHECKS_URL` only if you want healthchecks pings
- set `EXCLUDE_PATTERNS` for runtime data you do not want in the backup
- keep `.env` local and do not deploy it to the target machine

render the script with an explicit envsubst variable list

```sh
set -a
. ./.env
set +a

envsubst '${DATA_DIR} ${APP_NAME} ${BACKUP_DEST_TYPE} ${RCLONE_REMOTE} ${LOCAL_DEST_DIR} ${AGE_PUBLIC_KEY} ${HEALTHCHECKS_URL} ${RETENTION_DAYS} ${EXCLUDE_PATTERNS} ${AUTO_INSTALL_DEPS} ${LOCK_DIR}' < backup.sh.tmpl > backup.sh
chmod 700 backup.sh
```

copy the rendered script to the target host

```sh
scp backup.sh root@example-host:/opt/scripts/exampleapp-backup.sh
```

for r2 backups, configure rclone on the target host before running the script

```sh
scp rclone.conf root@example-host:/root/.config/rclone/rclone.conf
```

example cron entry

```cron
0 3 * * * /bin/sh /opt/scripts/exampleapp-backup.sh >> /var/log/exampleapp-backup.log 2>&1
```

restore a backup

- stop the service before restoring
- copy the encrypted archive to the host that has the age private key
- decrypt the archive
- extract it into a temporary restore directory
- inspect the files before replacing live data
- replace the app data directory with the restored files
- fix ownership and permissions if the service needs a specific user
- start the service
- check the app and logs before deleting the old data

example restore commands

```sh
age -d -i age-private-key.txt backup.tar.xz.age > backup.tar.xz
mkdir -p restore
xz -d -c backup.tar.xz | tar -C restore -xf -
```

notes

- sqlite wal shm and journal sidecar files are skipped when the base database is backed up
- healthchecks is optional and an empty url disables pings
- local backups are not pruned by this script
- r2 backups are pruned with rclone using `RETENTION_DAYS`
- overlapping runs are avoided with a lock directory
