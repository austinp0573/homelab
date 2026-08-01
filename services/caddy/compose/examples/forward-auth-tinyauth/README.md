# forward auth (tinyauth)

same idea as the nginx gate in `services/tinyauth/`, but caddy speaks to tinyauth directly.

tinyauth must be reachable from the caddy container (`tinyauth:3000` on a shared network, or host port via `host.docker.internal`). login UI gets its own hostname with no forward_auth. protected apps import the snippet before `reverse_proxy`.

cookie is set on the parent of the tinyauth app url, so login host and gated apps need a shared parent domain.

```caddyfile
{
	email you@example.com
	admin off
}

(tinyauth) {
	forward_auth tinyauth:3000 {
		uri /api/auth/caddy
		copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
	}
}

auth.example.com {
	reverse_proxy tinyauth:3000
}

app.example.com {
	import tinyauth
	reverse_proxy host.docker.internal:8080
}
```

order matters: `import tinyauth` before `reverse_proxy`.

this does not replace app-native auth for APIs (ntfy tokens, etc.). browser UIs only.


&nbsp;

**466f724a616e6574**
