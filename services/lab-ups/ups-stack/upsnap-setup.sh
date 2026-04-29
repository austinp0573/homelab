#!/bin/sh
set -eu

UPSNAP_USER="upsnap-shutdown"
UPSNAP_HOME="/home/${UPSNAP_USER}"
UPSNAP_SSH_DIR="${UPSNAP_HOME}/.ssh"
UPSNAP_AUTHORIZED_KEYS="${UPSNAP_SSH_DIR}/authorized_keys"
UPSNAP_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDxfqmz5hgaQFt3eNKvRMTZ7AemUh3UYaAE69YQ44sQ upsnap-shutdown"
SUDOERS_FILE="/etc/sudoers.d/upsnap-shutdown"
VISUDO_BIN=""

if ! command -v sudo >/dev/null 2>&1; then
  apt-get update
  apt-get install -y sudo
fi

if ! id "${UPSNAP_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${UPSNAP_USER}"
fi

install -d -m 700 -o "${UPSNAP_USER}" -g "${UPSNAP_USER}" "${UPSNAP_SSH_DIR}"
touch "${UPSNAP_AUTHORIZED_KEYS}"
chown "${UPSNAP_USER}:${UPSNAP_USER}" "${UPSNAP_AUTHORIZED_KEYS}"
chmod 600 "${UPSNAP_AUTHORIZED_KEYS}"

if ! grep -qxF "${UPSNAP_PUBLIC_KEY}" "${UPSNAP_AUTHORIZED_KEYS}"; then
  printf '%s\n' "${UPSNAP_PUBLIC_KEY}" >> "${UPSNAP_AUTHORIZED_KEYS}"
fi

cat > "${SUDOERS_FILE}" <<'EOF'
upsnap-shutdown ALL=(root) NOPASSWD: /sbin/shutdown, /usr/sbin/shutdown
EOF
chmod 440 "${SUDOERS_FILE}"

if command -v visudo >/dev/null 2>&1; then
  VISUDO_BIN="$(command -v visudo)"
elif [ -x /usr/sbin/visudo ]; then
  VISUDO_BIN="/usr/sbin/visudo"
elif [ -x /sbin/visudo ]; then
  VISUDO_BIN="/sbin/visudo"
fi

if [ -n "${VISUDO_BIN}" ]; then
  "${VISUDO_BIN}" -cf "${SUDOERS_FILE}"
else
  echo "WARNING: visudo not found; sudoers file was written but not syntax-checked." >&2
fi

if command -v su >/dev/null 2>&1; then
  su -s /bin/sh -c "sudo -n -l" "${UPSNAP_USER}" >/dev/null
fi

echo "UpSnap shutdown user is ready."
echo "Configured command: sudo /sbin/shutdown -h now"
