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
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ip='ip -color=auto'
alias df='df -h'
alias free='free -h'
alias top='top -d 1'
alias nerd='nerdctl'
alias nps='nerdctl ps -a'
alias nexec='nerdctl exec -it'
alias tree='tree -aAC'

c() {
    curl -s "cht.sh/$1"
}

export BAT_PAGING=never
EOF

cat > /etc/profile.d/20-prompt.sh << 'EOF'
if [ "$(id -u)" -eq 0 ]; then
    # Bold Red for root@hostname, Bold Blue for path
    export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
else
    # Bold Green for user@hostname, Bold Blue for path
    export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
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
echo "welcome to ${HOSTNAME:-$(hostname)} $(whoami) - DATE: $(date)"
if [ -s /etc/motd ]; then
    echo ""
    cat /etc/motd
fi
echo ""
EOF

chmod 644 /etc/profile.d/10-aliases.sh /etc/profile.d/20-prompt.sh /etc/profile.d/30-welcome.sh

# Enable color prompt in /root/.bashrc if present
if [ -f /root/.bashrc ]; then
    sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /root/.bashrc
fi

# root profile basics
if [ ! -f /root/.profile ] || ! grep -q 'EDITOR=vi' /root/.profile 2>/dev/null; then
    cat >> /root/.profile << 'EOF'

export EDITOR=vi
export PAGER=less
EOF
fi

sed -i '93d' ~/.bashrc

echo "shell ux installed"
