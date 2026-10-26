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


## PHP80 WordPressとPHP85 GBCの並行検証

PHP85ブランチの追加Composeを使う。旧 `container-php80` の起動スクリプトは同時実行しない。
既存の443番HTTPSプロキシで `localhost-gbc-pilot` をPHP85へ、`localhost-wp-only1-multi` を専用PHP80へ転送する。専用PHP80はホストポートを公開しない。

現在の検証コピーは `${DOCKER_VOLUME_DIR}/wp-only1-multi-php80-integration`、DBは同じ `local-db` 内の `wp-only1-multi-php85-integration`。元WordPress/GBC DBへアクセスできない専用ユーザーを使う。DBコンテナ・ボリュームは追加しない。コピーには既存ローカルWordPressの作業中のコードも含む。メール、外部HTTP、WP Cron、Action Schedulerの非同期起動を検証コピーだけで抑止する。

準備済み環境の起動と復帰:

```bash
./start_parallel_wp80.sh
./stop_parallel_wp80.sh
```

起動処理は専用WordPressのnginx/PHP-FPM設定、プロキシ切り替え、GBCのTRUSTED_PROXIES同期、両コンテナのローカル証明書信頼設定を行う。プロキシ切り替え時は短時間HTTPSが途切れる。PHP85のWebコンテナ・ワーカー・MariaDBは再作成しない。`.parallel-wp80-active` がある間、通常のstart/restart/stop/deleteは停止して専用コマンドへ誘導する。元に戻す場合も証明書ボリューム・複製DB・コピーしたファイルは残る。手動で `down -v` や `--remove-orphans` を実行しない。

起動時に公開証明書だけを `.local-certificates/` へ出力する。ブラウザーで未信頼なら、Mac側で `localhost-wp-only1-multi.crt` をキーチェーンへ追加してSSLの信頼を設定する。証明書検証を無効化しない。秘密鍵・認証情報はこのディレクトリに出力しない。

### 初回だけの準備（既存コピーには再実行しない）

```bash
./prepare_wp80_integration.sh /Users/kanji/development/docker_webserver_php80/wp-only1-multi
# コピー先・DBが既にあれば上書きせず停止する。非公開ダンプ保存先が表示される。
docker compose -f docker-compose.yml -f docker-compose.wp80-integration.yml up -d --no-deps wp80-integration
docker exec -i web-server-wp80-integration bash < files/wp80-integration/setup.sh
docker exec -i -u webapp web-server-wp80-integration php /dev/stdin < files/wp80-integration/configure.php
```

`configure.php` は確認済みのblog ID 5・商品ID 5（wallet-n1）だけを商品283の `wallet-n1-6` へ対応させ、対象サイトとrootサイトをHTTPSへ変更する。対象DB・商品・設定の存在を検証し、不一致なら停止する。出力する要約の `mail_intercepted` / `external_http_blocked` / `async_runner_disabled` が全てtrueであることを確認した後、コピー先直下に `.integration-ready` を作成して通常の並行起動へ進む。DBや商品が異なる環境で値を推測して実行しない。

準備スクリプトは全テーブルInnoDBを確認し、single-transactionで複製する。パスワードは生成してコピー側wp-config.phpだけへ保存する。中断時は部分的なコピー・DBを調査し、自動削除や上書きで再開しない。秘密情報・ダンプ・CookieをGitへ追加しない。

検証URL: `https://localhost-wp-only1-multi/gbc-pilot/product/wallet-n1/`。この中のiframeは `https://localhost-gbc-pilot/custom/standfield/wallet-n1-6` を参照する。シェアのpostMessageや選択状態復元のブラウザー検証は、環境起動の検証とは別に実施する。

並行モードでは `http://localhost-wp-only1-multi/` へのアクセスをパス・クエリーを維持して同ホストのHTTPSへ301転送する。80番はPHP85コンテナが保持するため、専用のホスト名別nginx設定をそこへ追加する。PHP85単独へ復帰する際にこの設定を削除する。


### AWS GBC test-3へ接続する別サイト（2026-10-27）

同じ検証用WordPressコピー・複製DB内に、blog **11**の`/gbc-aws-test3/`を追加した。元のblog5と元PHP80 WordPressは保持する。WordPress6.1.1／WooCommerce5.3.1／PHP8.0.28は維持した。

親ページ: `https://localhost-wp-only1-multi/gbc-aws-test3/product/php85-aws-test3-watch-belt/`。
WooCommerce商品181の`only1_custom_product_code=custom-order-watch-belt-2`、専用サイトのpartner=`ishikuni`・host=`https://gbc-pilot-test.goodbet.jp`で、新GBCの商品174（external_product_id=181）へ対応する。GBC側の商品設定は変更していない。

このサイトだけで、連携プラグインmaster **3a3ec8d84a8e996b4c588db7974f278d4f458d31 / 1.41.6**を別フォルダー`wp-only1-integration-woocommerce-plugin-aws-test3`から有効化する。blog5は元プラグインを維持する。通常の並行起動スクリプトをそのまま使え、AWS EC2の追加起動やSG変更は不要。

`isolation.php`はこのDB・domain・site pathだけに新testホストのHTTPS/443を追加許可する。他サイトの新testアクセスと他の外部HTTPは遮断する。WordPress側の`WP_ACCESSIBLE_HOSTS`にもホストを追加するが、mu-plugin側のsite制限は維持する。SSL検証、メール遮断、cron停止、非同期runner停止も維持する。

再構築が必要な場合だけ、既存サイト・フォルダーが無いことを確認し、固定masterのcloneと新testから取得したprivate JSONを用意して`./prepare_wp80_aws_test3.sh /private/path/gbc-config.json`を使用する。必要なJSON項目は`gbc_host`、`partner`、`product_slug`、`gbc_product_id`、`wc_product_id`、`price`、`api_key`。APIキーをGitや端末出力へ載せない。スクリプトは先に既存サイトを検出して拒否し、既存サイトの上書きや自動削除は行わない。作成前のDBダンプ・wp-configは非公開一時領域へ保存する。準備後は一時JSONの扱いを確認する。

HTTP/API/カートの確認は実施済みだが、postMessageと画像・価格の目視確認は実ブラウザーで別途行う。実施結果はアプリ側の`docs/php-platform-migration/execution-aws-wordpress-integration-2026-10-27.md`を参照する。
