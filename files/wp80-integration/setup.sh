#!/usr/bin/env bash
set -euo pipefail
# This script runs only in the dedicated WordPress container.
test -f /var/www/html/wp-only1-multi/wp-config.php
# Refuse a source configuration before PHP or HTTP can bootstrap WordPress.
php <<'PHP'
<?php
$config = file_get_contents('/var/www/html/wp-only1-multi/wp-config.php');
foreach (["define( 'DB_NAME', 'wp-only1-multi-php85-integration' );", "define( 'DB_USER', 'wp80_integration' );", "define('DISABLE_WP_CRON', true);"] as $required) {
    if (strpos($config, $required) === false) { fwrite(STDERR, "Isolation config missing\n"); exit(1); }
}
PHP
# Retain the upstream required by the image's default server.
cat > /etc/nginx/conf.d/php-fpm.conf <<'NGINX'
upstream php-fpm { server unix:/run/php-fpm/www.sock; }
NGINX
systemctl stop crond 2>/dev/null || true
systemctl disable crond 2>/dev/null || true
chown webapp:webapp /var/www/html/wp-only1-multi/wp-config.php
chmod 600 /var/www/html/wp-only1-multi/wp-config.php
chown -R webapp:webapp /var/www/html/wp-only1-multi/wp-content/uploads
nginx -t
systemctl restart php-fpm nginx
