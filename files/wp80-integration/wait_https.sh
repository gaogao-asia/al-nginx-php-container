#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a
proxy_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' https-portal-php85)
for attempt in {1..30}; do
  if docker exec "${CONTAINER_NAME}" curl --fail --silent --show-error --max-time 3 --resolve "localhost-gbc-pilot:443:$proxy_ip" -o /dev/null https://localhost-gbc-pilot/custom/standfield/wallet-n1-6 2>/dev/null; then exit 0; fi
  sleep 1
done
echo 'GBC HTTPS did not become ready.' >&2
exit 1
