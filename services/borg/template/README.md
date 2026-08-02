# borgmatic container sample

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### borgmatic

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | idle ~0 between jobs | ~30-60 MB if container stays up | image + caches, tens to hundreds of MB | idle |
| expected | 1-2 cores during backup | ~200-800 MB while borg runs | repo grows with retained archives | upload during backup / prune |
| high | multi-core | ~1-3 GB on big datasets | full backups + cache can be large | initial seed or check --verify-data |

### borgmatic-scheduled

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 0 when not firing | n/a between runs | same repo as borgmatic | none between runs |
| expected | same as borgmatic while the job runs | same as borgmatic while the job runs | cron/sidecar overhead negligible | backup window traffic |
| high | same peaks as borgmatic | same peaks as borgmatic | same | overlaps with other jobs if mis-scheduled |

Scheduled companion only changes when the job runs; treat peaks like borgmatic.

this directory is a deployment template for borgmatic in a container.

the intended workflow is simple.

1. copy this directory to the host that will run backups
2. copy `.env.example` to `.env`
3. fill in `.env`
4. put the passphrase and ssh files under `secrets/`
5. remove config and compose sections that do not apply
6. run the one shot service or the scheduled service

the default service runs `borgmatic create check`. it does not run prune, delete, or compact. that is intentional because the ssh users on truenas are expected to be append only.

## files

`compose.yml` is the container definition.

`config.yml` is the borgmatic configuration mounted into the container.

`.env.example` is the deployment variable template.

`secrets/` holds the passphrase file, ssh key, and known hosts file.

`scripts/` holds small helper scripts.

`notes/` holds deployment notes for specific parts of the setup.

`patterns/` holds examples for common backup shapes.

## normal run

copy `.env.example` to `.env`, edit it, then run the default service.

```sh
nerdctl compose run --rm borgmatic
```

or use docker compose or podman compose with the same file.

the scheduled service is present for hosts where a long running container is preferred.

```sh
nerdctl compose --profile scheduled up -d borgmatic-scheduled
```

host cron or a systemd timer that runs the one shot service is usually easier to reason about.

## first setup

read these in order when building a new deployment.

`notes/init-and-first-run.md`

`notes/encryption-and-secrets.md`

`notes/append-only-and-maintenance.md`

`notes/restore-and-ops.md`

## common edits

most deployments only need these values changed in `.env`.

`CLIENT_HOSTNAME`

`BACKUP_NAME`

`BORG_REMOTE_USER`

`BORG_REMOTE_REPO_PATH`

`HOST_ROOT`

`APP_DATA_PATH`

`LOCAL_REPO_ROOT`

the repository path should be stable. borg creates timestamped archives inside the repository.


&nbsp;

**466f724a616e6574**
