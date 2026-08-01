# multi-host (wildcard)

one site block for `*.example.com`, matchers per hostname. pairs well with DNS-01 for the wildcard cert.

on HTTP-01 you can still do multiple explicit host site blocks instead (see `../edge/`).

```caddyfile
{
	email you@example.com
	admin off
}

*.example.com {
	@app host app.example.com
	handle @app {
		reverse_proxy host.docker.internal:8080
	}

	@status host status.example.com
	handle @status {
		reverse_proxy host.docker.internal:8081
	}

	handle {
		abort
	}
}
```


&nbsp;

**466f724a616e6574**
