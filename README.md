# GBC local PHP 8.5 environment

`php85` branch of gaogao-asia/al-nginx-php-container. The existing
`container-php80` checkout, its image tags and database are not modified.

## Verified baseline

- AL2023 base: 2023.12.20261016.0, pinned linux/amd64 image digest in Dockerfile.
- Package repository: 2023.12.20261021, explicitly selected for patched PHP.
- PHP CLI/FPM 8.5.12; nginx 1.30.5; Composer 2.10.3.
- PHP includes GD, intl, zip, XML, MySQL and SQLite PDO extensions.
- systemd runs nginx, php-fpm and crond. Docker supplies networking, so the
  systemd-networkd wait-online unit is masked. Supervisor4.3.0 is included. Application workers and scheduler require the explicit
  setup below after a new container is created; migrations are separate.

## Setup

Copy `.env.dist` to `.env` and set DOCKER_VOLUME_DIR to the **new** application
parent (`/Users/kanji/development/docker_webserver_php85`). Never mount the PHP 8.0
application here: Composer modifies vendor and modules in the mounted checkout.
The new app and submodules use `migration/php85` and include the master regression tests.
Set `APP_DIRECTORY=gbc-third-winter13` to select the current Winter 1.3 / Laravel 13
candidate; nginx_config_update.sh and login.sh both honor this directory name.
The selected app nginx configuration must use the same root path.

The existing MariaDB `local-db` on `local-net` is reused. The PHP 8.5 application
must use its own cloned database and restricted account. Database credentials
belong in the application's ignored `.env`, not in this repository.

Build with `docker compose build php85-web`. Stop the PHP 8.0 Web/HTTPS containers
before starting this stack on the same host ports 80/443; do not delete them or stop
the database. Then run `./start.sh`. After preparing the candidate app and reviewing/archiving
cloned queued jobs, run `./setup_app_services.sh` to configure its workers and cron.

Open `https://localhost-gbc-pilot/` (existing /etc/hosts entry).
The separate HTTPS certificate is persisted in a project-specific named volume.
Browser trust must be checked; the start script does not change host trust settings.
For simultaneous comparison, set STANDARD_HTTP_PORT and HTTPS_PORT to unused ports
and verify redirects and browser session isolation explicitly.

## Operations

- `./start.sh`: create/start new stack, install app nginx configuration, restart FPM/nginx.
- `./stop.sh`: stop only this Compose project.
- `./restart.sh`: restart this project and reload application configuration.
- `./login.sh`: shell as webapp in the new app checkout.
- `./setup_app_services.sh`: configure/enable Supervisor workers and per-minute scheduler
  for the isolated local candidate. It rejects the original DB, cloud uploads and a
  nonempty jobs table. Re-run after container recreation; ordinary restart preserves it.
- `./delete.sh`: remove this project's containers while retaining certificates and external DB.
- `docker compose exec -u webapp php85-web vendor/bin/phpunit -c phpunit-platform.xml`:
  isolated regression suite, after compatible Composer dependencies are installed.

The start/stop scripts never retag spycetek/aep:latest, patch the old app, run winter:up,
copy cloud credentials, or start unconfigured queue workers. Explicit service setup
starts workers after its isolation and empty-queue checks. Existing queued payloads in a cloned DB
must not be executed against real services inadvertently.

## Current implementation status (2026-10-25 JST)

The image and TLS transport are working. The active app is `gbc-third-winter13`,
using PHP 8.5.12, Winter 1.3 development sources and Laravel 13.38.0. The regression
suite has 59 passing and 2 pre-existing skipped cases (61 total). The dedicated
MariaDB clone has been migrated; the original database schema and row counts were
unchanged. Home and login HTML, login assets, local image storage and thumbnail
creation have passed their respective checks. The 9-case GBC application integration suite also passed. Winter/Twig and PHP 8.5
runtime deprecations still occur during HTML rendering and remain unresolved.
Authenticated browser workflows,
queue execution, external integrations and EB deployment remain to be validated.

Authentication routes do not boot plugin middleware. The app therefore uses Winter's
core trusted-proxy configuration too. Its ignored local `.env` trusts only the HTTPS
container's exact IP. nginx_config_update.sh now reads the HTTPS container's actual
IP and synchronizes only TRUSTED_PROXIES in the selected app .env before restarting
FPM/nginx. start.sh and restart.sh invoke it. After manually recreating only the HTTPS
container, run ./nginx_config_update.sh too. The app .env keeps mode0600; no wildcard
trust or credential changes are introduced.

Consult the app's `docs/php-platform-migration/execution-winter13-2026-10-25.md`
for fixed upstream commits, local core fixes, known missing local images and the
remaining adoption criteria. Development Winter sources and local path repositories
are still validation candidates; the current lock alone is not portable to EB.


## Validation follow-up

Authenticated HTTP tests using a dedicated admin and inactive fixture product in the
cloned database passed login/2FA, Repeater add/save, image upload/removal, GBC image
synthesis and resize delivery. A random dedicated queue processed one harmless job;
existing jobs were not executed. Existing missing images will not be downloaded for
now: the user selected generated test images only. Browser JavaScript and visual
checks, Twig deprecations and always-on worker/cron behavior remain pending.

The HTTPS container exited with code 137 (OOMKilled=false) during verification.
The user freed port 443 and selected keeping the current configuration. Restart
succeeded and HTTPS is active again on 443; no port/APP_URL change was made.
The proxy IP remains 172.18.0.4. Authenticated create/update/preview and image delivery
returned 200 after further backend null-value fixes. Regression tests: 63 tests,
118 assertions, 61 passed and 2 existing skips; GBC integration: 9 passed.
Telescope pages and its filtered API returned 200; anonymous access returned 403.
Telescope's temporary web enablement was reverted to false. Twig API migration
and browser JavaScript/visual verification remain pending.


## Worker and Twig follow-up (2026-10-25 JST)

Supervisor4.2.5 failed to import pkg_resources with setuptools82.0.1. Dockerfile now
pins Supervisor4.3.0, and the r2 image was built and passed PHP8.5.12 / Supervisor CLI
checks. Compose selects `gbc-local/al2023-php85:eb-4.13.13-r2`.

The user selected archiving the 59 copied bulkFileManipulation jobs before starting
the normal queues. The private SQL is `/private/tmp/gbc-php85-worker/jobs-59.sql`;
it is not committed. The two workers processed harmless marker jobs as webapp,
Supervisor recovered a terminated idle worker, and failed_jobs stayed at 16.
The app uses database retry_after3660 and Supervisor stopwaitsecs3660 for the
3600-second file worker. The scheduler runs via `/etc/cron.d/gbc-php85` each minute.

Winter's local source fork now includes Twig parser/yield/capture compatibility
(commit488e30de); 74 regression tests: 72 passed, 2 pre-existing skips, 129assertions.
The separate GBC integration suite passed 9tests. Cold HTTP rendering of the custom
product page and backend forms passed with no new warning/error logs in that scope.
Browser JS/visual checks, cloud services, old job payloads and EB release/rollback
validation remain pending. Composer/installers CLI deprecation remains documented.


The Web container was then recreated from r2 and the documented nginx/service setup
was re-run successfully. Both workers processed marker jobs; cron ran; HTTPS stayed
on443 with the same proxy IP. Regression74tests passed with the same2existing skips.
After recreating a container, use `./start.sh` followed by `./setup_app_services.sh`
after reviewing pending jobs. A plain restart preserves the configured services.


The later CSV import check verified all131icons and531preview images on local disk.
A missing shared favorite PNG was copied from the public production CDN into the new
app only;147referenced local assets returned200. Null translation keys and list column
types were fixed in source forks; regression78tests:76passed,2existing skips.
The proxy IP later changed to172.18.0.3, producing a CSRF403 with the stale setting.
Automatic synchronization above fixes that restart/recreation case. Browser checks
remain pending; see the app docs/php-platform-migration/browser-validation-2026-10-25.md.
