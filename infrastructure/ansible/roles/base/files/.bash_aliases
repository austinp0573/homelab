# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# File listing
alias ls='ls --color=auto'
alias ll='ls -lArthR'
alias la='ls -A'
alias l='ls -Alrth'

# System info
alias cpu='lscpu | grep "Model name"'
alias mem='free -h'
alias disk='df -hT --total | grep -E "Filesystem|total"'
alias ports='sudo ss -tuln'
alias uptime='uptime -p'

# Package management
alias update='sudo apt update && sudo apt full-upgrade -y'
alias cleanapt='sudo apt autoremove -y && sudo apt clean'
alias pkglist='dpkg --get-selections | grep -v deinstall'

# Services / journal
alias syslog='sudo journalctl -p 3 -xb'
alias logs='sudo journalctl -xe'
alias s='sudo systemctl'
alias sc='sudo systemctl status'
alias sre='sudo systemctl restart'

# Networking
alias myip="ip -brief address show"
alias pingg="ping -c 4 8.8.8.8"
alias netcheck='ping -c 1 1.1.1.1 && echo OK || echo FAIL'

# commented out
# Git shortcuts
#alias gs='git status'
#alias ga='git add .'
#alias gc='git commit -m'
#alias gp='git push'

# Convenience
alias grep='grep --color=auto'
alias cls='clear'
alias please='sudo $(fc -ln -1)'
alias tree='tree -a -I '.git''