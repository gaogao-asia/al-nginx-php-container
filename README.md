# Web Server Container with Amazon Linux & Nginx & PHP
This is container running Nginx 1.20 with PHP 8.0 on Amazon Linux.  
This is prepared as development projects.

This environment downloads prebuilt image from [Docker Hub](https://cloud.docker.com/u/spycetek/repository/docker/spycetek/aep).  
Dockerfile is defined in [spycetek/aep](https://bitbucket.org/spycetek/aep) repository.

## About PHP Versions
* Tag 3.x: PHP 8.0
* Tag 2.x: PHP 7.4
* Tag 1.x: PHP 7.3

## Preparation
Create .env file by copying .env.dest file.

Change `DOCKER_VOLUME_DIR` variable to the local path you want to mount to container's document root of the web server.

In the example below, you should put directories of PHP projects under docker-www directory.
```
DOCKER_VOLUME_DIR=/Users/MyName/Documents/development/php_workspace/docker-www
```

```
/Users/MyName/Documents/development/php_workspace/docker-www/php-project1
/Users/MyName/Documents/development/php_workspace/docker-www/php-project2
```

You can also change `CONTAINER_NAME` and `HTTP_PORT` if you wish.


## Controlling Web Server Container
### Create docker network
If you have not created a docker network with the name specified in .env file,
create it with the command below. Example uses `local-net` as its name.  
If you already have it, skip to "Create & Start Container" section.

```
docker network create --driver bridge local-net
```

To see if it is created successfully, execute below.
```
docker network ls
```

If you want to remove the network, this is the command to do it.
```
docker network rm <network_name>
```

### Create and/or Start Container
Note: If it is the first time to use the latest container image, it will download an image of approximately 1GB. Do it under preferably fast and steady internet connection.

start.sh script creates the container if not exists yet,  
or starts container if there is one stopped.  
If it is running already, it dose nothing.
```
./start.sh
```

### Stop Container
stop.sh script stops the container, but not deletes it.
```
./stop.sh
```

### Delete Container
delete.sh delete the container. Data in the container will be lost.
```
./delete.sh
```

### Login to the Container
login.sh script lets you login to the container as `nginx` user.
```
./login.sh
```


## Check Web Server
In web browser on your local machine, open `http://localhost:50080/`.  
If the container is properly running, you should see the welcome page of Nginx.


## Updating Container & Having Multiple Web Server Containers
新しいdocker-compose.ymlでコンテナを作成・更新するには、
同じdocker-compose.ymlからは１つのコンテナしか作成できないため、
docker-compose.ymlのディレクトリごと複製して別途コンテナを作成するか、
既存のコンテナを削除して再作成する２つの方法がある。

### 既存のコンテナを保持する場合
* 既存のコンテナを作成したときのdocker-compose.ymlから変わっていない状態を維持しておく（更新しない）。
* docker-compose.ymlが含まれるリポジトリを別の場所に再度クローンし、.envを作成し、
  最新のコードでstart.shを実行する。.envのDOCKER_VOLUME_DIRは念の為異なるディレクトリを指定する。

### 既存のコンテナを破棄する場合
* 既存のコンテナを作成したdocker-compose.ymlはまだ更新しない
* docker-compose.ymlがあるディレクトリで、delete.shを実行する
* 削除が完了したら、git pullしてdoker-compose.ymlなどを最新にする
* .env.distを参考に.envを更新する（HTTPSが有効化されているためHTTPS_DOMAINSが必要になる）
* start.shを実行するとコンテナが作成されて起動する

### コンテナ作成後
* コンテナの共有フォルダを変更した場合、THIRDのプロジェクトファイル全体をそこへ移動する。
* コンテナにrootユーザでログインしてプロジェクトディレクトリにてcomposer installを実行する。
  （依存が既にインストール済みであっても、初回はディレクトリのパーミッション修正のために必要になる。）
