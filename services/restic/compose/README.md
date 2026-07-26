# restic compose

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### restic

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | idle ~0 when not running | ~20-40 MB if a long-lived wrapper is up | repo size is the real disk cost | idle |
| expected | 1-2 cores during backup | ~100-500 MB while running | temp pack space hundreds of MB; repo grows with source data | upload bandwidth bound during backup |
| high | all available cores unless GOMAXPROCS is set | ~1-4 GB on large repos / high concurrency | temp needs pack_size x (connections+1) | saturates uplink; prune/check can be heavy |

One restic template for either a selected set of host paths or one application
directory.

Use one profile per deployed copy. A host profile and an app profile are
alternatives, not two jobs to run from the same directory.

## profiles

### host profile

Use `.env.example.full` for a workstation or server where selected host paths
need backup.

The container mounts `/` read-only at `/host`. Restic only backs up paths in
`includes.txt`. The root mount keeps the template flexible without needing a
new compose file for every host.

`excludes.txt` is a second safety net. It excludes runtime files, caches,
container storage, the deployed template, and common junk. The examples assume
this template is deployed at `/opt/restic-client`.

`/host/mnt` is excluded because mounted storage should normally have its own
backup job. `/host/media` is excluded because bulk media usually needs a
separate retention policy. Remove either line if this host should back it up.

### app profile

Use `.env.example.app` for one application directory.

The app profile does not mount the host root. `backup.sh` stages the whole
`APP_SOURCE_DIR` with `rsync`, then replaces
`.db`, `.sqlite`, and `.sqlite3` files with SQLite hot backups. The repository
only receives `/app/<BACKUP_NAME>`.

If SQLite files are found and `sqlite3` is missing, the job fails. It does not
copy a live SQLite database as a fallback.

### sqlite only

When the snapshot should hold one hot-copied database and nothing else, use
`scripts/stage-sqlite.sh`. Do not use the app profile for this. `backup.sh`
still calls `stage-files.sh` and will rsync a whole directory.

`sqlite3` must be on the host. The script opens the live database, runs
`.backup`, and writes the result under `STAGE_DEST`. It does not touch WAL or
SHM sidecars in the staging tree.

Put these in `.env` (or export them before the script):

```sh
HOST_ROOT=./empty-host
RESTIC_HOST=example-host
COMPOSE_CMD=nerdctl compose

SQLITE_DB=/srv/example-app/db.sqlite3
STAGE_DEST=./staging/app/example-app
```

`STAGE_DEST` must be under `./staging/app/<name>`. The compose file mounts
`./staging/app` at `/app`, so restic sees `/app/<name>/db.sqlite3`. Keep
`<name>` simple: letters, numbers, dot, dash, and underscore.

Stage, then backup that path:

```sh
./scripts/stage-sqlite.sh
nerdctl compose run --rm restic backup /app/example-app --exclude-caches
```

Cron can chain the same two commands. There is no lock shared with
`backup.sh`, so do not schedule this beside another restic job against the
same repository on the same host without your own lock.

Restore lands under `/tmp/restic-restore/app/<name>/` the same way as an app
snapshot. The file name matches `basename` of `SQLITE_DB`.

## deploy

```sh
cp .env.example.full .env
# or
cp .env.example.app .env

cp includes.txt.example includes.txt
mkdir -p secrets certs staging/app /var/cache/restic/tmp
chmod 700 backup.sh scripts/*.sh
chmod 600 .env
```

Copy the secret examples to their real names and fill them in:

```sh
cp secrets/repo_location.txt.example secrets/repo_location.txt
cp secrets/password.txt.example secrets/password.txt

# only for a TrueNAS rest server
cp secrets/rest_username.txt.example secrets/rest_username.txt
cp secrets/rest_password.txt.example secrets/rest_password.txt
```

For S3, copy `secrets/aws_credentials.example` to
`secrets/aws_credentials` and set `AWS_SHARED_CREDENTIALS_FILE` in `.env`.

For ntfy with an access token:

```sh
cp secrets/ntfy_token.txt.example secrets/ntfy_token.txt
```

Set `NTFY_TOPIC` in `.env`. Leave the token file absent for a public topic.
Healthchecks and ntfy are both optional.

```sh
chmod 600 secrets/*
```

For a private HTTPS rest server, put the public certificate or CA at
`certs/truenas-ca.crt` and set:

```sh
RESTIC_CACERT=/certs/truenas-ca.crt
```

Do not put certificates in `secrets/`. Do not put a private key in `certs/`.

## configure

Set a stable `RESTIC_HOST` in `.env`. Do not change it casually because restic
uses it when grouping snapshots for retention.

For the host profile, edit `includes.txt`. Paths are container paths:

```text
/host/etc
/host/home
/host/root
/host/srv
/host/opt
```

For the app profile, set:

```sh
BACKUP_MODE=app
APP_SOURCE_DIR=/srv/example-app
BACKUP_NAME=example-app
```

`BACKUP_NAME` becomes the stable restored path under `/app/`. Keep it simple:
letters, numbers, dot, dash, and underscore.

The app profile needs `rsync`. It also needs `sqlite3` when the source contains
SQLite files.

**NOTES:**

* must use the `restic --insecure-tls` flag for all commands when backing up to local truenas with default SSL cert.

* `--exclude-if-present <filename>` can be used multiple times to exclude any directory and it's sub-directories if they contain the `<filename>`.

* `--dry-run -n -vv` set this at the end to perform a dry run that does not actually backup anything.

`overview-env.md` has notes for every variable kept in the profile examples.

## first backup

```sh
./scripts/init-repo.sh
./backup.sh
./scripts/snapshots.sh
```

The backup script uses a local lock. A second scheduled run exits instead of
running alongside the first.

## client schedule

Run one backup each day. This example keeps a local log:

```cron
0 2 * * * root /opt/restic-client/backup.sh >> /var/log/restic-backup.log 2>&1
```

Set `HEALTHCHECKS_URL` to receive success and failure pings. Set `NTFY_TOPIC`
to receive ntfy failure messages. The backup still works when neither is set.

## TrueNAS maintenance

Append-only rest-server clients cannot delete snapshots. Run retention on
TrueNAS against the local repository path, not from the backup client.

`../truenas/prune.sh` checks the repository before it prunes. By default it
checks 5 percent of repository data.

Example weekly TrueNAS cron job:

```cron
0 4 * * 0 root REPO_PATH=/mnt/coldpool/restic/admin/example-host PASSWORD_FILE=/root/restic-password.txt /path/to/prune.sh >> /var/log/restic-maintenance.log 2>&1
```

Example monthly full check and prune:

```cron
0 4 1 * * root CHECK_ARGS= REPO_PATH=/mnt/coldpool/restic/admin/example-host PASSWORD_FILE=/root/restic-password.txt /path/to/prune.sh >> /var/log/restic-maintenance.log 2>&1
```

Configure those commands in the TrueNAS Cron Jobs UI or another TrueNAS
scheduler. Adjust the repository path and retention variables as needed.

Do not run `forget --prune` from an append-only client. `forget` selects old
snapshots for removal. `prune` removes their unreferenced repository data.
Both require direct write access to the repository, which the TrueNAS job has.

## restore

Restore to a temporary directory first:

```sh
./scripts/restore.sh latest /tmp/restic-restore
```

Host snapshots restore below `/tmp/restic-restore/host/`. Restore only one
path when needed:

```sh
./scripts/restore.sh latest /tmp/restic-restore --include /host/etc
```

App snapshots restore below `/tmp/restic-restore/app/<BACKUP_NAME>/`. Stop the app before putting
restored data back in place. Keep the broken directory until the app starts
and its data looks right.

There is no scheduled restore job. Run a manual restore after a major change
or when you want to verify the recovery steps.

## helpers

- `backup.sh` runs one backup.
- `scripts/init-repo.sh` initializes a new repository.
- `scripts/snapshots.sh` lists snapshots.
- `scripts/check.sh` runs a client-side repository check when needed.
- `scripts/restore.sh` restores a snapshot to a host directory.
- `scripts/unlock.sh` removes stale locks after a failed job.
- `scripts/stage-files.sh` stages an app directory for the app profile.
- `scripts/stage-sqlite.sh` hot-copies one sqlite database into staging for a
  sqlite-only restic run.


&nbsp;

**466f724a616e6574**
