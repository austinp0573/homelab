#!/bin/bash
set -euo pipefail

tar cvf send.tar core/ lib/ optional/ profiles/ .env.example README.md setup.sh pack.sh
