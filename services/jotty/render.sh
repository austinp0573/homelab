#!/bin/bash

set -euo pipefail

set -a
. ./.env
set +a

envsubst '${JOTTY_SERVICE_NAME} ${JOTTY_IMAGE} ${JOTTY_CONTAINER_NAME} ${JOTTY_HOST_PORT} ${JOTTY_CONTAINER_PORT} ${JOTTY_NET} ${FRPC_IMAGE} ${FRPC_CONTAINER_NAME}' < compose.yml.tmpl > compose.yml

envsubst '${JOTTY_FRPC_SERVER_ADDR} ${JOTTY_FRPC_SERVER_PORT} ${JOTTY_FRPC_TOKEN} ${JOTTY_FRPC_TUNNEL_NAME} ${JOTTY_SERVICE_NAME} ${JOTTY_HOST_PORT} ${JOTTY_FRPC_CUSTOM_DOMAIN} ${JOTTY_FRPC_HTTP_AUTH_USER} ${JOTTY_FRPC_HTTP_AUTH_PASSWD} ${JOTTY_FRPC_HEALTHCHECK_TUNNEL_NAME} ${JOTTY_FRPC_HEALTHCHECK_CUSTOM_DOMAIN}' < frpc.toml.tmpl > frpc.toml


mkdir jotty-files

cp jotty-prepare.sh jotty-files/

mv frpc.toml compose.yml jotty-files/

tar cvf jotty-files.tar jotty-files/

rm -rf jotty-files/

zstd -f -19 -T0 jotty-files.tar -o jotty-files.tar.zst

rm -rf jotty-files.tar

printf "\nscp the files to the alpine destination &"
printf "\nrun the following:"
printf "\n----------------------"
printf "\nzstd -d jotty-files.tar.zst && rm jotty-files.tar.zst && tar xf jotty-files.tar && rm jotty-files.tar && mv jotty-files/* . && ./jotty-prepare.sh\n\n"
