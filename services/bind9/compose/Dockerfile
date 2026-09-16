FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0

ARG BIND_VERSION=9.20.29-r0
RUN apk add --no-cache "bind=${BIND_VERSION}" "bind-tools=${BIND_VERSION}" \
    && addgroup -S -g 10001 dns \
    && adduser -S -D -H -u 10001 -G dns dns \
    && mkdir -p /etc/bind /var/cache/bind /var/lib/bind \
    && chown dns:dns /var/cache/bind /var/lib/bind

USER 10001:10001
ENTRYPOINT ["/usr/sbin/named"]
CMD ["-g", "-4", "-n", "2", "-u", "dns", "-c", "/etc/bind/named.conf"]
