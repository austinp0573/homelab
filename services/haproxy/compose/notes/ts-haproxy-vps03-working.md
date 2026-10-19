```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy

    # AWS-LC Hardware-Accelerated TLS 1.3 Ciphers
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tlsv12

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend stats
    mode http
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 1s
    stats auth admin:supersecurepassword

frontend http_in
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/_.lock.tusko.org.pem alpn h2,http/1.1

    # Global HTTPS Enforcer
    http-request redirect scheme https unless { ssl_fc }

    # Client context headers passed to Nginx
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-For %[src]

    # Directly route all traffic to the single backend container
    default_backend nginx_backend

backend nginx_backend
    mode http
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host app.lock.tusko.org
    server nginx_container_1 100.116.166.73:8080 check inter 10000 fall 3 rise 2
```