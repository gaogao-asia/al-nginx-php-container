# PHP80 WordPressとPHP85 GBCの並行検証

GBCの基本構築は[アプリの構築手順](https://github.com/gaogao-asia/gbc-third/blob/master/docs/setup_local_dev_env.md)を先に完了します。通常のコンテナ操作は[README](../README.md)を参照します。

以下は移行検証で準備した既存WordPressコピーと商品/サイトIDに依存する構成です。新規参加者にその商品やDBが自動生成される手順ではありません。新しいデータへ適用する場合は、各スクリプトのDB名・サイト・商品guardを確認し、対応する検証データを準備してください。購入確定・決済・実メール送信は検証対象に含めません。


このリポジトリの追加Composeを使う。旧 `container-php80` の起動スクリプトは同時実行しない。
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

2026-10-27 税率準備の修正: site11へ税表示optionだけをコピーし、site5の税率行をコピーしていなかったため、GBC税込45,100円に対してカート41,000円となった。`copy_aws_test3_tax_rates.php`でsite11の空の税率表に元と同じ10%行を複製し、通常カートの単価/小計/合計45,100円（税4,100円）をHTTPで確認した。初回作成スクリプトにも同じ処理を追加した。既存税率の上書きは拒否し、site5の税率と既存Browserのカートは変更しない。WooCommerceカートはGET時に再計算するため、既存の検証カートは通常の再読み込みで確認する。

### AWS test検証時にローカルGBCを停止する構成

AWSのGBCをiframeに表示する`/gbc-aws-test3/`だけを検証する場合は、親WordPress・HTTPSプロキシ・DBだけでよい。ローカルGBCのupstream設定を残したままPHP85を停止すると、HTTPSプロキシ再起動時に名前解決で失敗するため、次の追加overrideを使う。

```sh
docker compose -f docker-compose.yml -f docker-compose.wp80-integration.yml -f docker-compose.wp80-aws-test3.yml up -d wp80-integration php85-https
docker stop web-server-php85
```

追加overrideはローカルGBCをprofile対象にし、HTTPSプロキシの依存先と配信ホストを親WordPressだけにする。既存証明書volumeとDBを再利用する。HTTPSの親WordPressは利用できるが、ローカルGBCと80番のHTTP転送は利用できない。このAWS専用モードの再起動には上の3ファイルを指定する。ローカルGBCも検証する従来の並行モードへ戻す際は、`docker compose up -d php85-web`でGBCを起動してから`./start_parallel_wp80.sh`を実行する。
