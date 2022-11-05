# Web Server Container for October Projects
This is container running Nginx 1.18 with PHP 7.3 on Amazon Linux.  
This is prepared as development environment for October CMS projects.

This environment downloads prebuilt image from [Docker Hub](https://cloud.docker.com/u/spycetek/repository/docker/spycetek/aep).  
Dockerfile is defined in [spycetek/aep](https://bitbucket.org/spycetek/aep) repository.

## Preparation
Create .env file by copying .env.dest file.

Change `DOCKER_VOLUME_DIR` variable to the local path you want to mount to container's document root of the web server.

In the example below, you should put directories of October projects under docker_october-web-server directory.
```
DOCKER_VOLUME_DIR=/Users/kanji/development/docker_october-web-server
```

```
/Users/kanji/development/docker_october-web-server/october-project1
/Users/kanji/development/docker_october-web-server/october-project2
```

You can also change `CONTAINER_NAME` and `HTTP_PORT` if you wish.


## Controlling Web Server Container
### Create docker network
If you have not created a docker network named `local-net`, create it with the command below.  
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


## Apply Project Specific Configuration for Nginx & PHP
### Nginx
追加のNginx設定ファイルを、ファイル名に`.conf`拡張子を付けてプロジェクトディレクトリの `.dev/nginx/` ディレクトリに格納することで、コンテナ内の`/etc/nginx/conf.d`にコピーされ適用される。nginx_config_update.sh, start.sh, restart.shで適用される。

### PHP
追加のPHP設定ファイルを、ファイル名に`.ini`拡張子を付けてプロジェクトディレクトリの `.dev/php/` ディレクトリに格納することで、コンテナ内の`/etc/php.d/`に`90-`プレフィクスが付けられてコピーされ適用される。nginx_config_update.sh, start.sh, restart.shで適用される。

### カスタムシェルスクリプト
プロジェクトに`.dev/container_hook.sh`というファイルを作成し、実行権限を付与(`chmod a+x .dev/container_hook.sh`)することで、nginx_config_update.sh, start.sh, restart.shでnginxとphpサービスリスタート直前に実行される。
