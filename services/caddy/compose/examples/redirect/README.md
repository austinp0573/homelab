# redirects

canonical host and http->https style redirects.

caddy already redirects http to https for hostname site blocks when HTTPS is enabled. the bits below are for www/apex and similar.

```caddyfile
{
	email you@example.com
	admin off
}

www.example.com {
	redir https://example.com{uri} permanent
}

example.com {
	reverse_proxy host.docker.internal:8080
}
```

path redirect:

```caddyfile
example.com {
	redir /old /new permanent
	reverse_proxy host.docker.internal:8080
}
```


&nbsp;

**466f724a616e6574**
