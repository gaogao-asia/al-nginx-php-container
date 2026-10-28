#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose -f docker-compose.yml -f docker-compose.wp80-integration.yml stop wp80-integration
docker compose -f docker-compose.yml up -d --no-deps php85-https
./nginx_config_update.sh
./files/wp80-integration/http_redirect.sh disable
./files/wp80-integration/wait_https.sh
rm -f .parallel-wp80-active
echo 'PHP85-only HTTPS routing restored. WordPress copy and DB are retained.'
