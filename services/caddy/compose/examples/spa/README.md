# spa fallback

static build where unknown paths should return `index.html` (react/vue/etc client routers).

```caddyfile
{
	email you@example.com
	admin off
}

app.example.com {
	root * /srv
	encode gzip
	try_files {path} /index.html
	file_server
}
```

mount the build output at `/srv` the same way as `../static-files/`.


&nbsp;

**466f724a616e6574**
