# basic auth

simple password gate on a site. hash the password with the caddy binary:

```sh
nerdctl run --rm caddy:alpine caddy hash-password --plaintext 'your-password'
```

paste the hash into the Caddyfile. do not put the plaintext password there.

```caddyfile
{
	email you@example.com
	admin off
}

app.example.com {
	basic_auth {
		# username  hash
		admin $2a$14$REPLACE_WITH_OUTPUT_OF_HASH_PASSWORD
	}
	reverse_proxy host.docker.internal:8080
}
```

fine for low-stakes stuff. for shared login across several apps, use tinyauth instead (`../forward-auth-tinyauth/`).


&nbsp;

**466f724a616e6574**
