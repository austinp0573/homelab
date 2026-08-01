# static files

serve a directory. mount the files into the container (see volume note below) and point `root` at that path.

```caddyfile
{
	email you@example.com
	admin off
}

static.example.com {
	root * /srv
	file_server
}
```

compose volume example:

```yaml
volumes:
  - ./Caddyfile:/etc/caddy/Caddyfile:ro
  - ./site:/srv:ro
  - ${DATA_DIR:-./data}:/data
```


&nbsp;

**466f724a616e6574**
