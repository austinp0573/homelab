#!/bin/sh

set -eu

cat << EOF | tee -a /etc/apk/repositories
@edge https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF


apk update
apk add nerdctl@edge
apk add containerd buildkit openssh-server openssh-sftp-server bat ripgrep bash bash-completion tzdata doas
apk upgrade

cp /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "America/Chicago" | tee /etc/timezone
apk del tzdata

rc-update add sshd default
rc-update add containerd default
rc-update add buildkitd default
rc-service sshd start
rc-service containerd start
rc-service buildkitd start

sysctl -w net.ipv4.ip_forward=1

cat << EOF | tee /etc/sysctl.d/99-forward-ipv4.conf
net.ipv4.ip_forward=1
EOF

ln -s /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh

cat << EOF | tee -a /etc/vim/vimrc
set nu
EOF

mkdir -p /root/.ssh
mkdir -p /etc/skel/.ssh

cat << 'EOF' | tee /etc/skel/.ssh/authorized_keys /root/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrvcJibgihLVGbQj09o6TEOD84hxTRgfzlFLoUO+JEZ dmz-01
EOF

chmod 700 /etc/skel/.ssh
chmod 600 /etc/skel/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

cat << 'EOF' | tee /etc/profile.d/15-bash-completion.sh
# Enable bash completion in interactive shells
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF

cat << 'EOF' | tee /etc/profile.d/10-basic-bash.sh
export ENV="$HOME/.bashrc"

# Custom Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias l='ls -Alrth'

# You may want to put all your additions into a separate file like
# ~/.ash_aliases, instead of adding them here directly.

if [ -f ~/.ash_aliases ]; then
    . ~/.ash_aliases
fi
EOF

echo -n "" > /etc/motd

cat << 'EOF' | tee /etc/profile.d/30-welcome-message.sh
clear

printf "\n"
fastfetch
printf "\n\n"
echo "welcome to $HOSTNAME $USER - Time: $(date)"
printf "\n\n"
EOF

adduser -h /home/austin -u 1000 -s /bin/bash -G wheel -D

echo 'permit persist :wheel' > /etc/doas.d/permit-persist-wheel.conf

sed -i '3i export EDITOR=vim' /etc/profile
