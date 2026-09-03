# environment reference

The two profile examples include the variables used by this template and the
backend variables that may be useful later. Leave unused values commented.

The compose file always uses these secret files:

```sh
RESTIC_REPOSITORY_FILE=/run/secrets/repo_location.txt
RESTIC_PASSWORD_FILE=/run/secrets/password.txt
RESTIC_CACHE_DIR=/cache
TMPDIR=/cache/tmp
```

Do not put repository passwords or access tokens directly in `.env`.

## template values

- `BACKUP_MODE` is `host` or `app`.
- `HOST_ROOT` is `/` for the host profile. The app profile points it at the
  empty template directory so the container cannot read the host root.
- `APP_SOURCE_DIR` is the live directory staged by the app profile.
- `BACKUP_NAME` is the stable app path in snapshots.
- `COMPOSE_CMD` is usually `nerdctl compose` or `docker compose`.
- `HEALTHCHECKS_URL` gets a success or failure ping after `backup.sh`.
- `NTFY_URL` defaults to `https://ntfy.sh`.
- `NTFY_TOPIC` enables ntfy failure messages.
- `NTFY_TOKEN_FILE` points at an optional ntfy bearer token file.
- `REST_USERNAME_FILE` and `REST_PASSWORD_FILE` hold rest-server basic auth.

## repository and password values

- `RESTIC_REPOSITORY` is a repository URL. This template normally uses the
  repository file instead.
- `RESTIC_REPOSITORY_FILE` is a file containing the repository URL.
- `RESTIC_PASSWORD` is the repository password. Avoid this in `.env`.
- `RESTIC_PASSWORD_FILE` is a file containing the repository password.
- `RESTIC_PASSWORD_COMMAND` is a command that prints the password.
- `RESTIC_KEY_HINT` selects a repository key to try first.

## rest server and TLS

- `RESTIC_REST_USERNAME` and `RESTIC_REST_PASSWORD` are rest-server basic
  auth. The helper scripts load them from the configured secret files.
- `RESTIC_CACERT` is a PEM file for a private CA or self-signed server.
- `RESTIC_TLS_CLIENT_CERT` is a combined client certificate and private key
  for mutual TLS.
- `RESTIC_INSECURE_TLS` disables certificate verification. Leave it blank.

## performance and behavior

- `RESTIC_HOST` is the snapshot host name. Keep it stable.
- `RESTIC_COMPRESSION` accepts `off`, `fastest`, `auto`, `better`, or `max`.
  `auto` is the normal setting.
- `RESTIC_PACK_SIZE` sets pack size in MiB. `64` is a reasonable default.
- `RESTIC_READ_CONCURRENCY` limits parallel local reads. Set a lower value on
  busy or spinning disks.
- `RESTIC_PROGRESS_FPS` limits progress output.
- `RESTIC_NO_CACHE` disables the local cache. Normally leave it blank.

## restic copy

These are only for `restic copy`.

- `RESTIC_FROM_REPOSITORY`
- `RESTIC_FROM_REPOSITORY_FILE`
- `RESTIC_FROM_PASSWORD`
- `RESTIC_FROM_PASSWORD_FILE`
- `RESTIC_FROM_PASSWORD_COMMAND`
- `RESTIC_FROM_KEY_HINT`

Use file variables for repository URLs and passwords when possible.

## S3 and compatible storage

- `AWS_SHARED_CREDENTIALS_FILE` points to a standard AWS credentials file.
- `AWS_PROFILE` selects a profile from that file.
- `AWS_DEFAULT_REGION` sets the region. R2 commonly uses `auto`.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` are
  direct credentials. Prefer the credentials file.
- `RESTIC_AWS_ASSUME_ROLE_ARN` enables an assumed IAM role.
- `RESTIC_AWS_ASSUME_ROLE_SESSION_NAME` names that role session.
- `RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID` sets an external ID.
- `RESTIC_AWS_ASSUME_ROLE_POLICY` supplies a session policy.
- `RESTIC_AWS_ASSUME_ROLE_REGION` sets the STS region.
- `RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT` overrides the STS endpoint.

## Azure

- `AZURE_ACCOUNT_NAME`
- `AZURE_ACCOUNT_KEY`
- `AZURE_ACCOUNT_SAS`
- `AZURE_ENDPOINT_SUFFIX`
- `AZURE_FORCE_CLI_CREDENTIAL`

`AZURE_ACCOUNT_KEY` and `AZURE_ACCOUNT_SAS` are secrets. Keep them out of
`.env`.

## Backblaze B2

- `B2_ACCOUNT_ID`
- `B2_ACCOUNT_KEY`

`B2_ACCOUNT_KEY` is a secret.

## Google Cloud Storage

- `GOOGLE_PROJECT_ID`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `GOOGLE_ACCESS_TOKEN`

`GOOGLE_APPLICATION_CREDENTIALS` should point to a mounted credential file.

## OpenStack Swift

- `OS_AUTH_URL`
- `OS_REGION_NAME`
- `OS_USERNAME`
- `OS_USER_ID`
- `OS_PASSWORD`
- `OS_TENANT_ID`
- `OS_TENANT_NAME`
- `OS_USER_DOMAIN_NAME`
- `OS_USER_DOMAIN_ID`
- `OS_PROJECT_NAME`
- `OS_PROJECT_DOMAIN_NAME`
- `OS_PROJECT_DOMAIN_ID`
- `OS_TRUST_ID`
- `OS_APPLICATION_CREDENTIAL_ID`
- `OS_APPLICATION_CREDENTIAL_NAME`
- `OS_APPLICATION_CREDENTIAL_SECRET`
- `OS_STORAGE_URL`
- `OS_AUTH_TOKEN`
- `ST_AUTH`
- `ST_USER`
- `ST_KEY`

The password, token, key, and application credential secret values are
secrets.

## rclone backend

- `RCLONE_BWLIMIT` limits rclone transfer bandwidth, for example `10M`.

Rclone itself may need its own configuration and credentials.
