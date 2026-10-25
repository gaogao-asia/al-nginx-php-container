#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a
compose=(docker compose -f docker-compose.yml -f docker-compose.wp80-integration.yml)
test -f "${DOCKER_VOLUME_DIR}/wp-only1-multi-php80-integration/.integration-ready" || {
  echo 'Prepare and verify the isolated WordPress copy and DB before starting.' >&2; exit 1;
}
for old in web-server-php80 https-portal; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "$old" 2>/dev/null || true)" == true ]]; then
    echo "Stop the old stack first: $old is running." >&2; exit 1
  fi
done
"${compose[@]}" config --quiet
# Preserve the selected mode even after a partial failure; stop_parallel_wp80.sh restores it.
touch .parallel-wp80-active
mkdir -p "${DOCKER_VOLUME_DIR}/wp-only1-multi-php80-integration/wp-content/mu-plugins"
touch "${DOCKER_VOLUME_DIR}/wp-only1-multi-php80-integration/wp-content/mu-plugins/000-integration-isolation.php"
"${compose[@]}" up -d --no-deps wp80-integration
ready=false
for attempt in {1..30}; do
  if docker exec web-server-wp80-integration systemctl is-active php-fpm >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
$ready || { echo 'WordPress PHP-FPM did not start.' >&2; exit 1; }
docker exec -i web-server-wp80-integration bash < files/wp80-integration/setup.sh
"${compose[@]}" up -d --no-deps php85-https
./nginx_config_update.sh
# https-portal creates local self-signed leaf certificates; trust only these exact public certificates.
for host in localhost-gbc-pilot localhost-wp-only1-multi; do
  cert=$(mktemp)
  copied=false
  for attempt in {1..30}; do
    if docker cp "https-portal-php85:/var/lib/https-portal/$host/local/signed.crt" "$cert" 2>/dev/null; then copied=true; break; fi
    sleep 1
  done
  if ! $copied; then rm -f "$cert"; echo "Certificate missing: $host" >&2; exit 1; fi
  mkdir -p .local-certificates
  cp "$cert" ".local-certificates/$host.crt"
  for container in web-server-wp80-integration "${CONTAINER_NAME}"; do
    docker cp "$cert" "$container:/etc/pki/ca-trust/source/anchors/$host-integration.crt"
    docker exec "$container" update-ca-trust extract
  done
  rm -f "$cert"
done
./files/wp80-integration/wait_https.sh
echo 'Parallel mode started. Both HTTPS hostnames use https-portal-php85.'
