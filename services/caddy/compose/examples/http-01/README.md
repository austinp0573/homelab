# http-01 tls

default path for stock `caddy:alpine`. caddy talks to let's encrypt over port 80.

dns A/AAAA for the hostname must point at this host. port 80 must be reachable from the internet (or from the acme validation path you are using).

```caddyfile
{
	email you@example.com
	admin off
}

app.example.com {
	reverse_proxy host.docker.internal:8080
}
```

no `tls` block needed for the normal public case - caddy enables HTTPS automatically when the site address looks like a hostname.


&nbsp;

**466f724a616e6574**
