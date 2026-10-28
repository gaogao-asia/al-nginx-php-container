#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a
APP_DIRECTORY=${APP_DIRECTORY:-gbc-third-winter13}
[[ "$APP_DIRECTORY" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid APP_DIRECTORY' >&2; exit 1; }
APP_PATH="/var/www/html/$APP_DIRECTORY"
# Local candidate only. Never start workers against the original DB or cloud uploads.
docker exec -u webapp -w "$APP_PATH" "$CONTAINER_NAME" php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
if (!app()->environment("local") || DB::connection()->getDatabaseName() !== "gbc-pilot-php85"
    || config("queue.default") !== "database" || config("cms.storage.uploads.disk") !== "local") {
    fwrite(STDERR, "Refusing service setup outside the isolated local candidate\n"); exit(1);
}
if (DB::table("jobs")->count() !== 0) {
    fwrite(STDERR, "Review/archive queued jobs before initial service setup\n"); exit(1);
}
'
docker exec -w "$APP_PATH" "$CONTAINER_NAME" bash .composer/setup_supervisord.sh
docker exec -i "$CONTAINER_NAME" bash -s -- "$APP_PATH" <<'CONTAINER'
set -euo pipefail
app_path=$1
touch /var/log/gbc-scheduler.log
chown webapp:webapp /var/log/gbc-scheduler.log
chmod 0640 /var/log/gbc-scheduler.log
printf 'SHELL=/bin/bash\nPATH=/usr/local/bin:/usr/bin:/bin\n* * * * * webapp cd %s && /usr/bin/php artisan schedule:run >> /var/log/gbc-scheduler.log 2>&1\n' "$app_path" > /etc/cron.d/gbc-php85
chmod 0644 /etc/cron.d/gbc-php85
systemctl enable --now crond
systemctl is-active supervisord crond
supervisorctl status
CONTAINER
