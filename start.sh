#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f .parallel-wp80-active ]]; then
    echo 'Parallel WordPress mode is selected. Use start_parallel_wp80.sh or stop_parallel_wp80.sh first.' >&2
    exit 1
fi
if [[ ! -f .env ]]; then echo 'Create .env from .env.dist first.' >&2; exit 1; fi
set -a; source .env; set +a
# No image retagging, no modification of PHP 8.0, and no automatic migrations/workers.
if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    echo "Required database network is absent: ${NETWORK_NAME}" >&2; exit 1
fi
docker compose up -d
for attempt in {1..30}; do
    if docker exec "${CONTAINER_NAME}" systemctl is-active php-fpm >/dev/null 2>&1; then break; fi
    sleep 1
done
./nginx_config_update.sh
