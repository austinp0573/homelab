# security headers

starting set I drop on public sites. tune per app (frames, CSP, etc.).

```caddyfile
{
	email you@example.com
	admin off
}

(headers_base) {
	header {
		X-Frame-Options "DENY"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
		Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
		-Server
	}
}

app.example.com {
	import headers_base
	reverse_proxy host.docker.internal:8080
}
```

HSTS only after you are sure the host will stay on HTTPS. `preload` is optional and sticky - skip it unless you mean it.


&nbsp;

**466f724a616e6574**
