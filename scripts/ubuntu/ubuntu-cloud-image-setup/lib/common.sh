# shared helpers for ubuntu-cloud-image-setup scripts
# expect ROOT_DIR to be set by the caller

if [ -z "${ROOT_DIR:-}" ]; then
    echo "ROOT_DIR is not set"
    exit 1
fi

ENV_FILE="$ROOT_DIR/.env"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "run as root: sudo $0"
        exit 1
    fi
}

load_env() {
    if [ ! -f "$ENV_FILE" ]; then
        echo "missing $ENV_FILE - copy .env.example to .env and edit it"
        exit 1
    fi

    if [ "$(stat -c '%a' "$ENV_FILE")" -gt 600 ]; then
        echo "$ENV_FILE must not be readable or writable by group or others"
        exit 1
    fi

    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a

    export LANG="${LOCALE:-en_US.UTF-8}"
    export LC_ALL="${LOCALE:-en_US.UTF-8}"
}

is_yes() {
    case "${1:-n}" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

is_no() {
    ! is_yes "${1:-n}"
}

pkg_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

apt_update_once() {
    stamp="${UBUNTU_SETUP_APT_STAMP:-}"
    if [ -n "$stamp" ] && [ -f "$stamp" ]; then
        return 0
    fi
    apt-get update -y
    if [ -n "$stamp" ]; then
        touch "$stamp"
    fi
}

apt_install() {
    apt_update_once
    if is_yes "${APT_INSTALL_RECOMMENDS:-n}"; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
    fi
}

apt_purge() {
    local pkg
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            echo "purging $pkg"
            DEBIAN_FRONTEND=noninteractive apt-get purge -y --no-autoremove "$pkg" || true
        fi
    done
}

service_enable() {
    systemctl enable --now "$1" 2>/dev/null || systemctl enable "$1" 2>/dev/null || true
}

service_disable() {
    systemctl disable --now "$1" 2>/dev/null || systemctl disable "$1" 2>/dev/null || true
    systemctl mask "$1" 2>/dev/null || true
}

ensure_dir() {
    mkdir -p "$1"
}

require_root
load_env
