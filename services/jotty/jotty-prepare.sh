#!/bin/sh

mkdir frpc-config

mv frpc.toml frpc-config/

mkdir -p config data/users data/checklists data/notes data/sharing data/encryption cache
chown -R 1000:1000 data/
chown -R 1000:1000 config/
chown -R 1000:1000 cache/

rm -rf jotty-prepare.sh jotty-files/

printf "\n\nnerd compose up -d\n\n"