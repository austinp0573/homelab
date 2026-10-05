#!/bin/sh

set -eu

install_dependencies() {
    if command -v curl >/dev/null 2>&1 \
        && command -v tar >/dev/null 2>&1 \
        && command -v gzip >/dev/null 2>&1 \
        && { [ -s /etc/ssl/certs/ca-certificates.crt ] \
            || [ -s /etc/pki/tls/certs/ca-bundle.crt ] \
            || [ -s /etc/ssl/ca-bundle.pem ]; }; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gzip tar
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache ca-certificates curl gzip tar
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ca-certificates curl gzip tar
    elif command -v microdnf >/dev/null 2>&1; then
        microdnf install -y ca-certificates curl gzip tar
    elif command -v yum >/dev/null 2>&1; then
        yum install -y ca-certificates curl gzip tar
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install ca-certificates curl gzip tar
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm --needed ca-certificates curl gzip tar
    elif command -v xbps-install >/dev/null 2>&1; then
        xbps-install -Sy ca-certificates curl gzip tar
    elif command -v emerge >/dev/null 2>&1; then
        emerge --noreplace app-arch/gzip app-arch/tar app-misc/ca-certificates net-misc/curl
    elif command -v eopkg >/dev/null 2>&1; then
        eopkg install -y ca-certs curl gzip tar
    else
        printf '%s\n' 'unable to install required dependencies' >&2
        exit 1
    fi
}

install_dependencies

case "$(uname -m)" in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    i386|i486|i586|i686) arch=i386 ;;
    *)
        printf 'unsupported architecture %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/google/yamlfmt/releases/latest)
tag=${release_url##*/}
version=${tag#v}
archive=yamlfmt_${version}_Linux_${arch}.tar.gz
download_url=https://github.com/google/yamlfmt/releases/download/${tag}/${archive}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

curl -fL --retry 3 -o "$workdir/$archive" "$download_url"
tar -xzf "$workdir/$archive" -C "$workdir"

mkdir -p /usr/local/bin /usr/local/share/doc/yamlfmt
install -m 0755 "$workdir/yamlfmt" /usr/local/bin/yamlfmt
install -m 0644 "$workdir/README.md" /usr/local/share/doc/yamlfmt/README.md
install -m 0644 "$workdir/LICENSE" /usr/local/share/doc/yamlfmt/LICENSE