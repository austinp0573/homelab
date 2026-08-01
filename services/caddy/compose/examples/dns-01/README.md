# dns-01 tls

needed when port 80 is not public (or you want a wildcard cert).

stock `caddy:alpine` does not include dns provider modules. build a custom image with the provider you use, then point `CADDY_IMAGE` at it. how that works is in `../../README.md`.

cloudflare example below. swap the module name / env var for route53, etc.

token stays out of the Caddyfile - pass it as an env var on the container (`environment` / `env_file` in compose).

```caddyfile
{
	email you@example.com
	admin off
	# optional: set once for every site
	# acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

*.example.com {
	tls {
		dns cloudflare {env.CLOUDFLARE_API_TOKEN}
	}

	@app host app.example.com
	handle @app {
		reverse_proxy host.docker.internal:8080
	}

	handle {
		abort
	}
}
```

without the dns module in the binary, caddy will fail at config load with a module-not-found style error.


&nbsp;

**466f724a616e6574**
