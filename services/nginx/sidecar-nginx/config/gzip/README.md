# gzip

compresses common text responses before they leave the sidecar. cheap win for html/js/css/json.

## swap in

```sh
NGINX_CONF=./config/gzip/nginx.conf
```

no extra volumes.

## notes

if the upstream already gzips, you can get double-work or weirdness. for most small homelab apps it is fine. skip binary types (already omitted from `gzip_types`).


&nbsp;

**466f724a616e6574**
