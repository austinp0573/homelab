ARG CADDY_VERSION=2.11

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN apk add --no-cache build-base brotli-dev

ENV GOTOOLCHAIN=auto \
    GOAMD64=v3 \
    GOFLAGS="-ldflags=-s -ldflags=-w" \
    CGO_ENABLED=1

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/greenpau/caddy-security \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/mholt/caddy-l4 \
    --with github.com/dunglas/caddy-cbrotli \
    --with github.com/hslatman/caddy-crowdsec-bouncer \
    --with github.com/mholt/caddy-events-exec

# Only helpful if using external storage.
# --with github.com/mohammed90/caddy-encrypted-storage
# Largely duplicates CrowdSec; enable only if you need a specific capability.
# --with pkg.jsn.cam/caddy-defender
# --with github.com/corazawaf/coraza-caddy/v2

RUN go install github.com/greenpau/go-authcrunch/cmd/authdbctl@latest

FROM caddy:${CADDY_VERSION}-alpine AS runner

RUN apk add --no-cache ncurses-libs gettext libmaxminddb

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /go/bin/authdbctl /usr/local/bin/authdbctl
COPY --from=allinurl/goaccess:latest /usr/bin/goaccess /usr/local/bin/goaccess
COPY --from=allinurl/goaccess:latest /usr/share /usr/share

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
