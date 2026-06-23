#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

set -a
source .env
set +a

printf "\nusing the templates & .env to hydrate alpine-answerfile.cfg & attach-answerfile.sh\n\n"

envsubst < alpine-answerfile.cfg.template > alpine-answerfile.cfg
envsubst $(cat .envsubst-vars) < attach-answerfile.sh.template > attach-answerfile.sh

printf "\nmaking attach-answerfile.sh executable\n\n"
chmod +x attach-answerfile.sh

printf "packaging everything for transport\n\n"

mkdir pve-alpine-setup
cp alpine-answerfile.cfg attach-answerfile.sh pve-alpine-setup/
tar -cvf - pve-alpine-setup/ | xz -9e > send-to-pve.tar.xz

printf "\ncleaning up\n\n"

rm -rf pve-alpine-setup/
rm -rf alpine-answerfile.cfg attach-answerfile.sh

printf "all done\n\n"
printf "scp -i ~/.ssh/<your_key> send-to-pve.tar.xz user@proxmox_hostname_or_IP\n\n"
printf "\nON PVE Host:\n"
printf "tar xf send-to-pve.tar.xz\n"
printf "cd pve-alpine-setup/\n"
printf "./attach-answerfile.sh\n\n"
