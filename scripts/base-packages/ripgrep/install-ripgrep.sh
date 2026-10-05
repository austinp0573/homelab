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

# use static builds across libc variants
case "$(uname -m)" in
    x86_64|amd64) target=x86_64-unknown-linux-musl ;;
    aarch64|arm64) target=aarch64-unknown-linux-musl ;;
    armv7|armv7l) target=armv7-unknown-linux-musleabihf ;;
    s390x) target=s390x-unknown-linux-gnu ;;
    *)
        printf 'unsupported architecture %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/BurntSushi/ripgrep/releases/latest)
tag=${release_url##*/}
version=${tag#v}
archive=ripgrep-${version}-${target}.tar.gz
download_url=https://github.com/BurntSushi/ripgrep/releases/download/${tag}/${archive}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

curl -fL --retry 3 -o "$workdir/$archive" "$download_url"
tar -xzf "$workdir/$archive" -C "$workdir"
source_dir=$workdir/ripgrep-${version}-${target}

mkdir -p \
    /etc/bash_completion.d \
    /usr/local/bin \
    /usr/local/share/fish/vendor_completions.d \
    /usr/local/share/man/man1 \
    /usr/local/share/zsh/site-functions

install -m 0755 "$source_dir/rg" /usr/local/bin/rg
install -m 0644 "$source_dir/doc/rg.1" /usr/local/share/man/man1/rg.1
install -m 0644 "$source_dir/complete/rg.bash" /etc/bash_completion.d/rg
install -m 0644 "$source_dir/complete/rg.fish" /usr/local/share/fish/vendor_completions.d/rg.fish
install -m 0644 "$source_dir/complete/_rg" /usr/local/share/zsh/site-functions/_rg