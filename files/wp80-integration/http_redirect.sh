#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a
case "${1:-}" in
  enable)
    docker exec -i "${CONTAINER_NAME}" sh -c 'cat > /etc/nginx/conf.d/wp80-http-redirect.conf' < files/wp80-integration/http-redirect.conf
    ;;
  disable)
    docker exec "${CONTAINER_NAME}" rm -f /etc/nginx/conf.d/wp80-http-redirect.conf
    ;;
  *) echo 'Usage: http_redirect.sh enable|disable' >&2; exit 1 ;;
esac
docker exec "${CONTAINER_NAME}" nginx -t
docker exec "${CONTAINER_NAME}" systemctl reload nginx
