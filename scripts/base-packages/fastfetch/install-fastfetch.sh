#!/bin/sh

set -eu

install_dependencies() {
    if command -v curl >/dev/null 2>&1 \
        && command -v tar >/dev/null 2>&1 \
        && command -v gzip >/dev/null 2>&1 \
        && { [ -s /etc/ssl/certs/ca-certificates.crt ] \
            || [ -s /etc/pki/tls/certs/ca-bundle.crt ] \
            || [ -s /etc/ssl/ca-bundle.pem ]; } \
        && { [ -r /usr/share/bash-completion/bash_completion ] \
            || [ -r /etc/bash_completion ]; }; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y bash-completion ca-certificates curl gzip tar
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash-completion ca-certificates curl gzip tar
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bash-completion ca-certificates curl gzip tar
    elif command -v microdnf >/dev/null 2>&1; then
        microdnf install -y bash-completion ca-certificates curl gzip tar
    elif command -v yum >/dev/null 2>&1; then
        yum install -y bash-completion ca-certificates curl gzip tar
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install bash-completion ca-certificates curl gzip tar
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm --needed bash-completion ca-certificates curl gzip tar
    elif command -v xbps-install >/dev/null 2>&1; then
        xbps-install -Sy bash-completion ca-certificates curl gzip tar
    elif command -v emerge >/dev/null 2>&1; then
        emerge --noreplace app-arch/gzip app-arch/tar app-misc/ca-certificates app-shells/bash-completion net-misc/curl
    elif command -v eopkg >/dev/null 2>&1; then
        eopkg install -y bash-completion ca-certs curl gzip tar
    else
        printf '%s\n' 'unable to install required dependencies' >&2
        exit 1
    fi
}

install_dependencies

case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=aarch64 ;;
    armv7|armv7l) arch=armv7l ;;
    i386|i486|i586|i686) arch=i686 ;;
    loongarch64) arch=loongarch64 ;;
    ppc64le) arch=ppc64le ;;
    riscv64) arch=riscv64 ;;
    s390x) arch=s390x ;;
    *)
        printf 'unsupported architecture %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

libc=gnu
for musl_loader in /lib/ld-musl-*.so.1 /usr/lib/ld-musl-*.so.1; do
    if [ -e "$musl_loader" ]; then
        libc=musl
        break
    fi
done

if [ "$libc" = musl ]; then
    if [ "$arch" != amd64 ]; then
        printf 'unsupported architecture and libc %s %s\n' "$arch" "$libc" >&2
        exit 1
    fi
    archive=fastfetch-musl-amd64.tar.gz
else
    case "$arch" in
        amd64|aarch64) archive=fastfetch-linux-${arch}-polyfilled.tar.gz ;;
        *) archive=fastfetch-linux-${arch}.tar.gz ;;
    esac
fi

release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/fastfetch-cli/fastfetch/releases/latest)
tag=${release_url##*/}
download_url=https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/${archive}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

curl -fL --retry 3 -o "$workdir/$archive" "$download_url"
tar -xzf "$workdir/$archive" -C "$workdir"
source_dir=$workdir/${archive%.tar.gz}/usr

# preserve the packaged usr hierarchy under usr local
mkdir -p /usr/local
cp -R "$source_dir/." /usr/local/
mkdir -p /etc/bash_completion.d
install -m 0644 /usr/local/share/bash-completion/completions/fastfetch /etc/bash_completion.d/fastfetch
chmod 0755 /usr/local/bin/fastfetch