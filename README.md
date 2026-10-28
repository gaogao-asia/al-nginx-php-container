# GBC PHP85コンテナ

`gaogao-asia/al-nginx-php-container`のPHP85環境です。アプリと別リポジトリで管理し、旧PHP80定義は`php80`ブランチへ保持しています。

**初回構築は[アプリのローカル構築手順](https://github.com/gaogao-asia/gbc-third/blob/master/docs/setup_local_dev_env.md)から進めてください。** clone・`/etc/hosts`・DB/APP_KEY・Composer・HTTPS・ワーカー起動までの順序はそちらを正本とします。このREADMEはコンテナの構成と操作を説明します。

## 構成と設定

- `Dockerfile`：AL2023の固定amd64ベース、PHP 8.5.12、nginx、Composer、Supervisor。正確なOS/package pinはDockerfileが正です。
- `docker-compose.yml`：`php85-web`（`web-server-php85`）と`php85-https`（`https-portal-php85`）。
- `.env.dist`：Webの設定例。コピー先の`.env`はGit管理外です。
- `mariadb/`：**DBがない場合だけ**使う[独立したMariaDB定義](mariadb/README.md)。Web Composeから自動起動しません。
- `docs/wordpress-integration.md`：任意の[PHP80 WordPress並行検証](docs/wordpress-integration.md)。

`DOCKER_VOLUME_DIR`はアプリの親ディレクトリ、`APP_DIRECTORY`はその中のアプリ名（通常`gbc-third`）。親を`/var/www/html`へマウントします。nginx設定は選択アプリのテンプレートからrootを反映したコピーを作り、アプリの追跡ファイルを変更しません。

Web用`.env`の標準ポートはHTTP 80と50085、HTTPS 443、HTTPSプロキシのHTTP入口50086です。`STANDARD_HTTP_PORT` / `HTTP_PORT` / `HTTPS_PORT` / `HTTPS_HTTP_PORT`で変更できます。標準URLを変える場合はアプリのURL・リダイレクト・親ストア設定も確認します。

`local-net`は外部ネットワーク、`local-db`は共有MariaDBです。既存PHP80や他アプリとホストの80/443が競合する場合は、対象Web/HTTPSを停止してから起動します。DBのデータ領域や他プロジェクトのコンテナは流用・削除しません。

## Operations

このリポジトリのルートで実行します。アプリの依存・`.env`・DBが準備済みであることが前提です。

```sh
./start.sh                 # Web/HTTPS起動、nginx・proxy設定を反映
./login.sh                 # webappで選択アプリへ入る
./restart.sh               # 再起動と設定反映
./stop.sh                  # このWeb/HTTPSプロジェクトだけ停止
./delete.sh                # コンテナ削除。証明書volumeと外部DBは保持
```

`start.sh`はmigration・依存インストール・ワーカーの初期設定を実行しません。初回/コンテナ再作成後、アプリ構築手順の確認を終えてから`./setup_app_services.sh`を実行します。通常のrestartでは既存設定を維持します。

`setup_app_services.sh`は`APP_ENV=local`、DB名`gbc-pilot-php85`、database queue、local uploads、jobs空を検査し、2系統workerと毎分schedulerを設定します。別名DBは現在のguard対象外です。未実行ジョブを無条件に削除する処理はありません。

```sh
docker compose ps
docker compose logs --tail=100 php85-https
docker exec web-server-php85 systemctl status nginx php-fpm supervisord crond
docker exec web-server-php85 supervisorctl status
```

`docker compose logs`はsystemd配下の全ログを集約しません。アプリは選択アプリの`storage/logs/`、workerは`/var/log/october-worker-*.log`、schedulerは`/var/log/gbc-scheduler.log`、PHP-FPMは`/var/log/php-fpm/www-error.log`を確認します。

## HTTPS・403・再作成

HTTPS証明書は専用volumeへ保存します。ホスト側の公開証明書の信頼設定はアプリ構築手順にあります。単体起動スクリプトはmacOSのキーチェーン設定を変更しません。

`nginx_config_update.sh`はHTTPSコンテナの実IPを取得し、選択アプリの`.env`に`TRUSTED_PROXIES`を同期してnginx/PHP-FPMを再起動します。固定IPやワイルドカードを手で設定しません。HTTPSだけを再作成した後や403が出る場合は、アプリ設定・証明書・両コンテナの起動を確認して実行します。

```sh
./nginx_config_update.sh
```

WordPress並行モードの`.parallel-wp80-active`がある場合、通常のstart/restart/stop/deleteは専用コマンドへ誘導します。切替と復帰は[WordPress手順](docs/wordpress-integration.md)を使います。`down -v`や`--remove-orphans`で証明書・検証コンテナを一括削除しません。

## 検証記録

過去の移行結果はアプリの[移行記録](https://github.com/gaogao-asia/gbc-third/tree/master/docs/php-platform-migration)へまとめています。固定ソース、現在の手順、当時の未完了事項を区別して参照してください。
