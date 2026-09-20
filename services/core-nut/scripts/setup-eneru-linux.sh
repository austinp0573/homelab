#!/bin/sh

set -eu

ENERU_USER="${ENERU_USER:-eneru-shutdown}"
POWER_OFF_WRAPPER="/usr/local/sbin/eneru-poweroff"
SUDOERS_FILE="/etc/sudoers.d/eneru-shutdown"

: "${SSH_PUBKEY:?SSH_PUBKEY environment variable is required}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run this script as root." >&2
    exit 1
fi

# TrueNAS is handled by the separate TrueNAS script.
if command -v midclt >/dev/null 2>&1; then
    echo "Error: TrueNAS detected. Use setup-eneru-truenas.sh instead." >&2
    exit 1
fi

case "$SSH_PUBKEY" in
    ssh-*|ecdsa-*) ;;
    *)
        echo "Error: SSH_PUBKEY does not look like an SSH public key." >&2
        exit 1
        ;;
esac


# ---------------------------------------------------------------------------
# Install sudo if necessary
# ---------------------------------------------------------------------------

if ! command -v sudo >/dev/null 2>&1; then
    echo "Installing sudo..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y sudo

    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache sudo

    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sudo

    elif command -v yum >/dev/null 2>&1; then
        yum install -y sudo

    else
        echo "Error: sudo is required and no supported package manager was found." >&2
        exit 1
    fi
fi


# ---------------------------------------------------------------------------
# Create dedicated user
# ---------------------------------------------------------------------------

if ! id "$ENERU_USER" >/dev/null 2>&1; then
    echo "Creating user: $ENERU_USER"

    if command -v useradd >/dev/null 2>&1; then
        useradd \
            -m \
            -s /bin/sh \
            -c "Eneru UPS shutdown" \
            "$ENERU_USER"

    elif command -v adduser >/dev/null 2>&1; then
        adduser \
            -D \
            -h "/home/$ENERU_USER" \
            -s /bin/sh \
            "$ENERU_USER"

    else
        echo "Error: no supported user creation command found." >&2
        exit 1
    fi

    # Give the account an unknown random password.
    # Eneru still authenticates exclusively with its SSH key.
    RANDOM_PASSWORD=$(
        od -An -N32 -tx1 /dev/urandom |
        tr -d ' \n'
    )

    printf '%s:%s\n' "$ENERU_USER" "$RANDOM_PASSWORD" |
        chpasswd

    unset RANDOM_PASSWORD
fi


# ---------------------------------------------------------------------------
# Install SSH public key
# ---------------------------------------------------------------------------

HOME_DIR=$(
    awk -F: -v user="$ENERU_USER" \
        '$1 == user { print $6; exit }' /etc/passwd
)

if [ -z "$HOME_DIR" ]; then
    echo "Error: could not determine home directory for $ENERU_USER." >&2
    exit 1
fi

mkdir -p "$HOME_DIR/.ssh"

printf '%s\n' "$SSH_PUBKEY" \
    > "$HOME_DIR/.ssh/authorized_keys"

chown -R "$ENERU_USER" "$HOME_DIR/.ssh"

chmod 0700 "$HOME_DIR/.ssh"
chmod 0600 "$HOME_DIR/.ssh/authorized_keys"


# ---------------------------------------------------------------------------
# Install one common graceful-poweroff command
# ---------------------------------------------------------------------------

cat > "$POWER_OFF_WRAPPER" <<'EOF'
#!/bin/sh

set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: eneru-poweroff" >&2
    exit 2
fi

# systemd systems: Debian, Ubuntu, Proxmox, etc.
if [ -r /proc/1/comm ] &&
   [ "$(cat /proc/1/comm)" = "systemd" ] &&
   command -v systemctl >/dev/null 2>&1; then

    exec "$(command -v systemctl)" poweroff
fi

# Traditional/OpenRC Linux.
if command -v shutdown >/dev/null 2>&1; then
    exec "$(command -v shutdown)" -h now
fi

# Final conventional Linux fallback.
if command -v poweroff >/dev/null 2>&1; then
    exec "$(command -v poweroff)"
fi

echo "Error: no supported poweroff command found." >&2
exit 1
EOF

chown root:root "$POWER_OFF_WRAPPER"
chmod 0755 "$POWER_OFF_WRAPPER"


# ---------------------------------------------------------------------------
# Allow only the poweroff wrapper through sudo
# ---------------------------------------------------------------------------

mkdir -p /etc/sudoers.d

cat > "$SUDOERS_FILE" <<EOF
$ENERU_USER ALL=(root) NOPASSWD: $POWER_OFF_WRAPPER
EOF

chown root:root "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$SUDOERS_FILE" >/dev/null
fi


echo
echo "Eneru shutdown user configured."
echo
echo "User: $ENERU_USER"
echo "Eneru shutdown_command:"
echo "  sudo -n $POWER_OFF_WRAPPER"
