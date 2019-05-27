# Web Server Container for October Projects
This is container running Nginx 1.14 with PHP 7.2 on Amazon Linux.  
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
