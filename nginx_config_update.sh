#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a
APP_DIRECTORY="${APP_DIRECTORY:-gbc-third}"
[[ "$APP_DIRECTORY" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Invalid APP_DIRECTORY" >&2; exit 1; }
proxy_ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' https-portal-php85)
docker exec -i -u webapp "${CONTAINER_NAME}" php /dev/stdin "$proxy_ip" "/var/www/html/$APP_DIRECTORY" < files/update_trusted_proxy.php
docker exec -e APP_DIRECTORY="$APP_DIRECTORY" "${CONTAINER_NAME}" bash -euc '
  app_root="/var/www/html/$APP_DIRECTORY"
  test -f "$app_root/.dev/nginx/local-docker.conf"
  ln -sfn "$app_root/.dev/nginx/local-docker.conf" /etc/nginx/conf.d/gbc-third.conf
  mkdir -p "$app_root/storage/logs" "$app_root/storage/framework/cache"
  chown -R webapp:webapp "$app_root/storage"
  nginx -t
  systemctl restart php-fpm nginx
'
