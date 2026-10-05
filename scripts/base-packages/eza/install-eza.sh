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
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    armv7|armv7l) arch=arm ;;
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

case "$arch:$libc" in
    x86_64:gnu) target=x86_64-unknown-linux-gnu ;;
    x86_64:musl) target=x86_64-unknown-linux-musl ;;
    aarch64:gnu) target=aarch64-unknown-linux-gnu ;;
    arm:gnu) target=arm-unknown-linux-gnueabihf ;;
    *)
        printf 'unsupported architecture and libc %s %s\n' "$arch" "$libc" >&2
        exit 1
        ;;
esac

release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/eza-community/eza/releases/latest)
tag=${release_url##*/}
version=${tag#v}
binary_archive=eza_${target}.tar.gz
completion_archive=completions-${version}.tar.gz
man_archive=man-${version}.tar.gz
download_base=https://github.com/eza-community/eza/releases/download/${tag}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM
mkdir -p "$workdir/bin" "$workdir/completions" "$workdir/man"

# eza publishes support files as separate archives
curl -fL --retry 3 -o "$workdir/$binary_archive" "$download_base/$binary_archive"
curl -fL --retry 3 -o "$workdir/$completion_archive" "$download_base/$completion_archive"
curl -fL --retry 3 -o "$workdir/$man_archive" "$download_base/$man_archive"
tar -xzf "$workdir/$binary_archive" -C "$workdir/bin"
tar -xzf "$workdir/$completion_archive" -C "$workdir/completions"
tar -xzf "$workdir/$man_archive" -C "$workdir/man"

bash_completion=$(find "$workdir/completions" -type f \( -name eza -o -name eza.bash \) | head -n 1)
fish_completion=$(find "$workdir/completions" -type f -name eza.fish | head -n 1)
zsh_completion=$(find "$workdir/completions" -type f -name _eza | head -n 1)
man_one=$(find "$workdir/man" -type f -name eza.1 | head -n 1)
man_five=$(find "$workdir/man" -type f -name eza_colors.5 | head -n 1)

mkdir -p \
    /etc/bash_completion.d \
    /usr/local/bin \
    /usr/local/share/fish/vendor_completions.d \
    /usr/local/share/man/man1 \
    /usr/local/share/man/man5 \
    /usr/local/share/zsh/site-functions

install -m 0755 "$workdir/bin/eza" /usr/local/bin/eza
install -m 0644 "$bash_completion" /etc/bash_completion.d/eza
install -m 0644 "$fish_completion" /usr/local/share/fish/vendor_completions.d/eza.fish
install -m 0644 "$zsh_completion" /usr/local/share/zsh/site-functions/_eza
install -m 0644 "$man_one" /usr/local/share/man/man1/eza.1
install -m 0644 "$man_five" /usr/local/share/man/man5/eza_colors.5