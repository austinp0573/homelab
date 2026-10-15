#!/bin/sh

# Truncate/create clean HTTP access log file
> /data/access.log
rm -f /data/stats.html

# Start GoAccess real-time dashboard daemon in background on port 7890
goaccess /data/access.log \
  -o /data/stats.html \
  --log-format=CADDY \
  --real-time-html \
  --port=7890 \
  --origin=https://stats.${ROOT_DOMAIN} \
  --ws-url=wss://stats.${ROOT_DOMAIN}:443/ws &

# Generate authdbctl configuration 
mkdir -p /root/.config/authdbctl
cat << EOF > /root/.config/authdbctl/config.yaml
base_url: "https://auth.${ROOT_DOMAIN}/auth"
username: "${CADDY_AUTHDB_USERNAME}"
password: "${CADDY_AUTHDB_PASSWORD}"
realm: "local"
token_path: "/root/.config/authdbctl/token.jwt"
EOF

# Start Caddy in foreground
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
