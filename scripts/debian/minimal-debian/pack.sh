#!/bin/bash
set -euo pipefail

[ -f "./.env" ] && printf "\nENV ALREADY PRESENT, pack.sh will not tamper with a current .env\n" && exit 1

cp .env.example .env

tar cvf send.tar core/ lib/ optional/ profiles/ .env setup.sh 

rm .env