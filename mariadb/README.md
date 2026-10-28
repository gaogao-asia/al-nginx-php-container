# 任意のローカルMariaDB

GBC用の既存`local-db`がない場合だけ使います。MariaDB 10.11.16を`local-net`へ接続し、ホストからは`127.0.0.1:53306`、同ネットワークのコンテナからは`local-db:3306`で接続します。GBC固有のDB/ユーザー/データ・APP_KEYの準備は[アプリの構築手順](https://github.com/gaogao-asia/gbc-third/blob/master/docs/setup_local_dev_env.md#3-mariadbと開発専用db)を参照します。

## 既存DBを使う場合

`docker ps -a --filter name=local-db`で確認します。既存コンテナが停止中なら、元のCompose定義または`docker start local-db`で再開します。このディレクトリのComposeを重ねて起動しません。既存の保存先・認証・共有DBを継続使用します。

## 初めてDBを用意する場合

コンテナリポジトリの`mariadb/`で実行します。

```sh
docker network inspect local-net >/dev/null 2>&1 || docker network create local-net
cp .env.dist .env
```

`.env`の`MARIADB_ROOT_PASSWORD`へ自分のローカル管理者パスワードを設定します。Web用の`../.env`とは別ファイルです。データは既定でこのディレクトリの`mariadb_data/`へ保存します。空の新規領域を使い、旧MySQLのデータ領域は直接マウントしません。

```sh
chmod 600 .env
docker compose up -d
docker compose ps
```

healthがhealthyになってからアプリのDB作成へ進みます。初期化後に`.env`のパスワードだけ変更しても既存DBアカウントは変更されません。

## 通常操作

```sh
docker compose logs --tail=100 local-db
docker compose stop
# 再開
docker compose up -d
```

DBはWebと別のComposeプロジェクトなので、Web側のstop/deleteでは停止・削除されません。他のローカルアプリでも共有している場合はDBを止める前に利用状況を確認します。

この定義はmacOSで検証した設定（`lower_case_table_names=2`）を引き継いでいます。Linux等の大文字小文字を区別するデータ保存先では、初期化前に設定の適合を確認してください。MySQLからMariaDBへの既存データ移行・切り戻しツールは含めず、GBC初回構築用の任意のDB起動定義を提供します。
