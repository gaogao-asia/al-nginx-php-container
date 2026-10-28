#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a
APP_DIRECTORY="${APP_DIRECTORY:-gbc-third}"
[[ "$APP_DIRECTORY" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Invalid APP_DIRECTORY" >&2; exit 1; }
docker compose exec --user webapp --workdir "/var/www/html/$APP_DIRECTORY" php85-web bash
