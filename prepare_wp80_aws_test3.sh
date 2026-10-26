#!/usr/bin/env bash
# One-off AWS test site provisioning in the already isolated WordPress copy.
set -euo pipefail
cd "$(dirname "$0")"
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo 'Usage: prepare_wp80_aws_test3.sh PRIVATE_GBC_CONFIG_JSON [PINNED_PLUGIN_REPO]' >&2; exit 2
fi
private_config="$1"
test -f "$private_config"
set -a; source .env; set +a
wp_copy="${DOCKER_VOLUME_DIR}/wp-only1-multi-php80-integration"
plugin_source="${2:-${DOCKER_VOLUME_DIR}/dependencies/wp-only1-integration-woocommerce-plugin}"
pin=3a3ec8d84a8e996b4c588db7974f278d4f458d31
plugin_target="$wp_copy/wp-content/plugins/wp-only1-integration-woocommerce-plugin-aws-test3"
test -f "$wp_copy/.integration-ready"
# Detect an existing target before creating backups, copying files or changing configuration.
docker exec -i --user webapp web-server-wp80-integration php <<'PHP_CHECK'
<?php
$_SERVER['HTTP_HOST']='localhost-wp-only1-multi';$_SERVER['REQUEST_URI']='/gbc-pilot/';
$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']=443;$_SERVER['REMOTE_ADDR']='127.0.0.1';
define('WP_USE_THEMES',false);require '/var/www/html/wp-only1-multi/wp-load.php';
if(DB_NAME!=='wp-only1-multi-php85-integration'){file_put_contents('php://stderr',"Wrong DB; refused.\n");exit(2);}
if(get_blog_id_from_url('localhost-wp-only1-multi','/gbc-aws-test3/')){
    file_put_contents('php://stderr',"AWS test site already exists; inspect it instead of overwriting.\n");exit(3);
}
PHP_CHECK
[[ "$(git -C "$plugin_source" rev-parse HEAD)" == "$pin" ]]
[[ -z "$(git -C "$plugin_source" status --porcelain)" ]]
[[ ! -e "$plugin_target" ]] || { echo 'Plugin target exists; inspect it first.' >&2; exit 3; }
umask 077
private_work=$(mktemp -d "${TMPDIR:-/tmp}/gbc-wp-aws-test3.XXXXXX")
trap 'docker exec web-server-wp80-integration rm -f /tmp/gbc-aws-test3-private.json >/dev/null' EXIT
docker exec local-db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot --single-transaction --skip-lock-tables --hex-blob wp-only1-multi-php85-integration' > "$private_work/wordpress-before.sql"
cp "$wp_copy/wp-config.php" "$private_work/wp-config-before.php"
chmod 600 "$private_work/wordpress-before.sql" "$private_work/wp-config-before.php"
python3 - "$wp_copy/wp-config.php" <<'PY_CONFIG'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
old="define('WP_ACCESSIBLE_HOSTS', 'localhost-gbc-pilot,localhost-wp-only1-multi');"
new="define('WP_ACCESSIBLE_HOSTS', 'localhost-gbc-pilot,localhost-wp-only1-multi,gbc-pilot-test.goodbet.jp');"
if old in s:s=s.replace(old,new)
elif new not in s:raise SystemExit('Unexpected HTTP allowlist; refused')
p.write_text(s);p.chmod(0o600)
PY_CONFIG
mkdir -m 755 "$plugin_target"
(umask 022; git -C "$plugin_source" archive "$pin" | tar -xf - -C "$plugin_target")
docker exec -i --user webapp web-server-wp80-integration sh -c 'umask 077; cat > /tmp/gbc-aws-test3-private.json' < "$private_config"
docker exec -i --user webapp web-server-wp80-integration php < files/wp80-integration/configure_aws_test3.php > "$private_work/site-created.json"
cat "$private_work/site-created.json"
printf 'Private provisioning records: %s\n' "$private_work"
