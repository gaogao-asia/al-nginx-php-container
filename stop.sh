#!/bin/bash

# Network name is hardcoded in docker-compose.yml
NETWORK_NAME=local-net

# cd to the directory where this file exists
cd $( dirname "${BASH_SOURCE[0]}" )
if [[ ! -f .env ]]
then
  echo ".env file is missing. Create based on .env.dist."
  exit 1
fi

source .env

RED='\033[0;31m'
docker ps &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Please make sure that docker app is started."
fi

status=`docker inspect -f {{.State.Running}} $CONTAINER_NAME 2> /dev/null`
if [ $? -eq 1 ]; then # container not exist yet
    set +x
    echo "$CONTAINER_NAME container does not exist."
else
    if [ "$status" = "false" ]; then # container not running
        set +x
        echo "$CONTAINER_NAME container is already stopped."
    else
        docker exec -it $CONTAINER_NAME systemctl stop nginx
        docker exec -it $CONTAINER_NAME systemctl stop php-fpm
        sleep 2s

        docker-compose stop
    fi
fi
