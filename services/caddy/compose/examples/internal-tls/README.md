# internal tls

caddy's own CA. browsers will complain unless you trust it. fine for lab boxes and tailnet-only names where you do not want public ACME.

```caddyfile
{
	admin off
	local_certs
}

app.lab {
	tls internal
	reverse_proxy host.docker.internal:8080
}
```

`local_certs` in the global block makes internal the default. or set `tls internal` per site like above.


&nbsp;

**466f724a616e6574**
