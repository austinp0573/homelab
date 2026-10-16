# single service

one hostname, one backend. starting point for most app deploys.

```caddyfile
{
	email you@example.com
	admin off
}

app.example.com {
	reverse_proxy host.docker.internal:8080
}
```


&nbsp;

**466f724a616e6574**
