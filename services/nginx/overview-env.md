# nginx env

`sidecar-nginx/` is the reusable pattern stack under this tree.

## pattern conf notes (edit the file, not `.env`)

| pattern | notable defaults | purpose + notes |
| --- | --- | --- |
| proxy | `proxy_pass http://placeholder:80` | default reverse-proxy pattern to the demo upstream. change upstream host when wiring a real service on the compose network. missing upstream DNS = 502 with healthy nginx. Missing upstream DNS is a healthy nginx serving 502s — check compose networks first. |
| basic-auth | needs `./secrets/htpasswd` | generate with `htpasswd.sh`; mount must be uncommented. empty/missing htpasswd fails auth or nginx start depending on config. prefer Tinyauth at the edge for SSO instead of proliferating htpasswd. Prefer Tinyauth at the edge once you outgrow scattered htpasswd files. |
| static | needs `./static` mount | serves files from a mounted directory; uncomment the volume. forgetting the mount yields 404s for everything. good for tiny status pages, not for app backends. Uncomment the static volume or every path 404s. |
| rate-limit | `rate=10r/s`, `burst=20` | nginx limit_req style defaults in the pattern — tune for your abuse model. too tight breaks browsers with parallel assets; too loose does nothing. zone memory is in the conf — don’t forget it when copying snippets. Too tight breaks browsers loading many assets; too loose does nothing useful. |
| cache | zone `10m`, valid `200 10m` | proxy cache pattern; needs the cache volume uncommented or nginx errors. caching authenticated/personalized content is a footgun — know what’s safe. purge/restart behavior depends on the volume. Do not cache personalized or authenticated responses without thinking. |
| websockets | timeouts `3600s` | Upgrade/Connection headers + long read/send timeouts. too-short timeouts kill sticky WS sessions through the proxy. HAProxy in front needs matching timeouts too. Match long timeouts on HAProxy in front or WS sessions die at the edge. |
| tls | listen 443 + certs | publish 443 and mount cert/key paths the conf expects. self-signed is fine for lab; clients must trust or ignore. without mounts, nginx fails on SSL listen. Without cert mounts, nginx fails as soon as it tries to listen on 443. |
| kitchen-sink | combines most | reference mash-up — don’t deploy as-is without trimming. useful to see how directives interact; conflicts teach more than they serve traffic. copy out only what you need. Copy out only the directives you need; the mash-up is a reference, not a deploy. |

uncomment optional volume mounts when a pattern needs them. prefer Tinyauth for SSO at the edge.
