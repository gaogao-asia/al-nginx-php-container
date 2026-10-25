#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose restart
./nginx_config_update.sh
