# scheduling

the default service is one shot.

prefer a host cron job or systemd timer when the host already has good scheduling.

that keeps the container simple and makes failures visible in the host logs.

example cron shape.

```sh
0 3 * * * cd /path/to/borgmatic-deployment && nerdctl compose run --rm borgmatic
```

the scheduled service exists for hosts where a long running container is easier.

```sh
nerdctl compose --profile scheduled up -d borgmatic-scheduled
```

set `SCHEDULE_SECONDS` in `.env`.

the scheduled service uses a basic sleep loop. it is intentionally plain.
