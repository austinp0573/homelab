FROM alpine:3.24

RUN apk add --no-cache \
        nut \
        tini \
    && command -v upsc >/dev/null \
    && command -v upscmd >/dev/null \
    && command -v upsrw >/dev/null \
    && command -v upsd >/dev/null \
    && command -v upsdrvctl >/dev/null \
    && test -x /usr/lib/nut/snmp-ups

COPY entrypoint.sh /usr/local/sbin/nut-entrypoint

RUN chmod 0755 /usr/local/sbin/nut-entrypoint

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/sbin/nut-entrypoint"]
