#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "shell ux"

# clear default motd noise; keep file for alerts if something writes it
: > /etc/motd

cat > /etc/profile.d/10-aliases.sh << 'EOF'
alias ls='ls --color=auto'
alias l='ls --color=auto -Alrth'
alias df='df -h'
alias free='free -h'
alias top='top -d 1'
alias nerd='nerdctl'

c() {
    curl -s "cht.sh/$1"
}
EOF

cat > /etc/profile.d/20-prompt.sh << 'EOF'
if [ "$(id -u)" -eq 0 ]; then
    export PS1='${USER:-root}@${HOSTNAME%%.*}:${PWD}# '
else
    export PS1='${USER}@${HOSTNAME%%.*}:${PWD}$ '
fi
EOF

cat > /etc/profile.d/30-welcome.sh << 'EOF'
# only for interactive shells
case $- in
    *i*) ;;
    *) return ;;
esac

clear
echo ""
command -v fastfetch >/dev/null 2>&1 && fastfetch
echo ""
echo "welcome to $HOSTNAME $(whoami) - DATE: $(date)"
if [ -s /etc/motd ]; then
    echo ""
    cat /etc/motd
fi
echo ""
EOF

chmod 644 /etc/profile.d/10-aliases.sh /etc/profile.d/20-prompt.sh /etc/profile.d/30-welcome.sh

# root profile basics
if [ ! -f /root/.profile ] || ! grep -q 'EDITOR=vi' /root/.profile 2>/dev/null; then
    cat >> /root/.profile << 'EOF'

export EDITOR=vi
export PAGER=less
EOF
fi

echo "shell ux installed"
