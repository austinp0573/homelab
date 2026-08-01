# websocket

`reverse_proxy` already upgrades websockets. usually you do not need extra config.

if a backend is picky about Host / X-Forwarded-*, set headers explicitly. leave Connection/Upgrade alone.

```caddyfile
{
	email you@example.com
	admin off
}

draw.example.com {
	reverse_proxy host.docker.internal:5000
}

collab.example.com {
	reverse_proxy host.docker.internal:5001
}
```

collab-style services often need the public ws/wss url configured on the app side too - that is not a caddy problem.


&nbsp;

**466f724a616e6574**
