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
  # Install a rendered copy: an alternate clone name must not require editing the app.
  template="$app_root/.dev/nginx/local-docker.conf"
  [[ $(grep -Ec "^[[:blank:]]*root[[:blank:]]+" "$template") == 1 ]]
  config=$(mktemp /etc/nginx/conf.d/.gbc-third.XXXXXX)
  trap "rm -f -- $config" EXIT
  sed -E "s@^([[:blank:]]*root[[:blank:]]+)/var/www/html/[A-Za-z0-9_-]+;[[:blank:]]*\$@\1$app_root;@" "$template" > "$config"
  grep -Eq "^[[:blank:]]*root[[:blank:]]+$app_root;[[:blank:]]*$" "$config"
  chmod 0644 "$config"
  mv -fT "$config" /etc/nginx/conf.d/gbc-third.conf
  mkdir -p "$app_root/storage/logs" "$app_root/storage/framework/cache"
  chown -R webapp:webapp "$app_root/storage"
  nginx -t
  systemctl restart php-fpm nginx
'
