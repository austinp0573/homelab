# app data backup

for a single app, set `APP_DATA_PATH` in `.env`.

example.

`APP_DATA_PATH=/srv/my-app`

the compose file mounts it here.

`/source/app`

then add `/source/app` to `source_directories` if the deployment should only back up that app.

or keep `/source/host` and use exclude patterns to keep the backup narrow.

for docker or nerdctl compose apps, back up the bind mount directories and the compose project directory.

avoid backing up container overlay storage unless there is a specific reason.

prefer app aware dumps for databases.

filesystem backups are fine for static files, uploads, configs, and stopped services.
