#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# defaults (override in .env)
HAPROXY_FULL_SETUP="${HAPROXY_FULL_SETUP:-n}"
HAPROXY_EMAIL="${HAPROXY_EMAIL:-}"
HAPROXY_DOMAINS="${HAPROXY_DOMAINS:-}"

echo "haproxy"

# shellcheck disable=SC1091
. /etc/os-release
codename="${VERSION_CODENAME:-bookworm}"
major="${VERSION_ID%%.*}"

install_haproxy_30() {
    apt_install curl ca-certificates gnupg
    ensure_dir /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/haproxy-archive-keyring.gpg ]; then
        curl -fsSL https://haproxy.debian.net/haproxy-archive-keyring.gpg \
            -o /etc/apt/keyrings/haproxy-archive-keyring.gpg
    fi
    echo "deb [signed-by=/etc/apt/keyrings/haproxy-archive-keyring.gpg] https://haproxy.debian.net ${codename}-backports-3.0 main" \
        > /etc/apt/sources.list.d/haproxy.list
    rm -f /tmp/minimal-debian-apt-updated
    apt_update_once
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "haproxy=3.0.*"
}

# debian 13 already ships 3.0 in main; older releases use haproxy.debian.net
if [ -n "${major:-}" ] && [ "$major" -ge 13 ] 2>/dev/null; then
    apt_install haproxy
    echo "haproxy from debian ($VERSION_ID)"
else
    echo "adding haproxy.debian.net 3.0 for $codename"
    install_haproxy_30 || {
        echo "haproxy.debian.net failed, falling back to distro haproxy"
        rm -f /etc/apt/sources.list.d/haproxy.list
        rm -f /tmp/minimal-debian-apt-updated
        apt_install haproxy
    }
fi

ensure_dir /etc/haproxy/certs
ensure_dir /etc/haproxy/errors
chmod 750 /etc/haproxy/certs

# skeleton config — edit backends as needed
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 2048

    # ssl defaults (used once certs exist under /etc/haproxy/certs)
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor
    option  http-server-close
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# http -> https (also used for certbot webroot challenges if you switch to webroot later)
frontend fe_http
    bind *:80
    mode http

    # acme http-01 (certbot standalone stops haproxy; webroot can use this path)
    acl is_acme path_beg /.well-known/acme-challenge/
    use_backend be_acme if is_acme

    redirect scheme https code 301 if !is_acme

frontend fe_https
    bind *:443 ssl crt /etc/haproxy/certs/
    mode http

    # example host -> backend
    # acl host_app hdr(host) -i app.example.com
    # use_backend be_app if host_app

    default_backend be_default

backend be_acme
    mode http
    # only needed if using webroot; point at a local path server or leave unused
    server localhost 127.0.0.1:9080

backend be_default
    mode http
    # placeholder — replace with a real backend (tailscale ip, local container, etc)
    # server app1 127.0.0.1:8080 check
    http-request return status 503 content-type text/plain string "no backend configured\n"

# backend be_app
#     mode http
#     option httpchk GET /healthz
#     server app1 100.64.0.10:8080 check
EOF

# minimal error files if package did not ship them
for code in 400 403 408 500 502 503 504; do
    f="/etc/haproxy/errors/${code}.http"
    if [ ! -f "$f" ]; then
        printf 'HTTP/1.0 %s\r\nCache-Control: no-cache\r\nConnection: close\r\nContent-Type: text/html\r\n\r\n' "$code" > "$f"
    fi
done

# dummy cert so ssl bind does not fail before real certs exist
if [ ! "$(ls -A /etc/haproxy/certs 2>/dev/null)" ]; then
    echo "creating self-signed placeholder cert"
    apt_install openssl
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /tmp/haproxy-placeholder.key \
        -out /tmp/haproxy-placeholder.crt \
        -subj "/CN=localhost" 2>/dev/null
    cat /tmp/haproxy-placeholder.crt /tmp/haproxy-placeholder.key > /etc/haproxy/certs/placeholder.pem
    rm -f /tmp/haproxy-placeholder.key /tmp/haproxy-placeholder.crt
    chmod 640 /etc/haproxy/certs/placeholder.pem
    chown root:haproxy /etc/haproxy/certs/placeholder.pem 2>/dev/null || true
fi

# renew hook: build haproxy pems from live certs
ensure_dir /etc/haproxy/scripts
cat > /etc/haproxy/scripts/install-certs.sh << 'EOF'
#!/bin/bash
# sync letsencrypt live certs into /etc/haproxy/certs as pem files
set -euo pipefail
live=/etc/letsencrypt/live
out=/etc/haproxy/certs
[ -d "$live" ] || exit 0
for d in "$live"/*; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ "$name" = "README" ] && continue
    if [ -f "$d/fullchain.pem" ] && [ -f "$d/privkey.pem" ]; then
        cat "$d/fullchain.pem" "$d/privkey.pem" > "$out/${name}.pem"
        chmod 640 "$out/${name}.pem"
        chown root:haproxy "$out/${name}.pem" 2>/dev/null || true
    fi
done
systemctl reload haproxy 2>/dev/null || true
EOF
chmod 755 /etc/haproxy/scripts/install-certs.sh

service_enable haproxy
systemctl reload haproxy 2>/dev/null || systemctl restart haproxy

if is_yes "$HAPROXY_FULL_SETUP"; then
    echo "HAPROXY_FULL_SETUP=y"
    if [ -z "$HAPROXY_EMAIL" ] || [ -z "$HAPROXY_DOMAINS" ]; then
        echo "need HAPROXY_EMAIL and HAPROXY_DOMAINS for certbot"
        exit 1
    fi

    apt_install certbot

    ensure_dir /etc/letsencrypt/renewal-hooks/deploy
    ln -sf /etc/haproxy/scripts/install-certs.sh /etc/letsencrypt/renewal-hooks/deploy/haproxy-certs.sh

    # standalone needs :80 — briefly stop haproxy
    systemctl stop haproxy
    # shellcheck disable=SC2086
    if ! certbot certonly --standalone --non-interactive --agree-tos \
        -m "$HAPROXY_EMAIL" \
        $(for d in $HAPROXY_DOMAINS; do printf -- '-d %s ' "$d"; done); then
        systemctl start haproxy
        exit 1
    fi

    /etc/haproxy/scripts/install-certs.sh
    # drop placeholder once real certs exist
    if ls /etc/haproxy/certs/*.pem >/dev/null 2>&1; then
        rm -f /etc/haproxy/certs/placeholder.pem
    fi
    systemctl start haproxy
    echo "certs installed for: $HAPROXY_DOMAINS"
else
    echo "HAPROXY_FULL_SETUP=n (skeleton only; set y + EMAIL/DOMAINS for certbot)"
fi

echo "haproxy done"
