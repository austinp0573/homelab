#!/bin/bash

set -a
source ./.env
set +a
envsubst < compose.yml.template > compose.yml