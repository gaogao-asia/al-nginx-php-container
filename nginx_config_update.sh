#!/bin/bash

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
    exit;
fi

# Create docker network if necessary
docker network inspect $NETWORK_NAME &> /dev/null
if [ $? -ne 0 ]; then
    set -x
    docker network create --driver bridge $NETWORK_NAME
    set +x
fi

status=`docker inspect -f {{.State.Running}} $CONTAINER_NAME 2> /dev/null`
if [ $? -eq 1 ]; then # container not exist yet
    echo "$CONTAINER_NAME container does not exist. Use start.sh instead."
    exit
else
    if [ "$status" = "false" ]; then # container not running
        echo "$CONTAINER_NAME container is not running. Use start.sh instead."
        exit
    fi
fi

# Delete all broken symbolic links to nginx config files
docker exec -it $CONTAINER_NAME sh -c 'cd /etc/nginx/conf.d && find -L . -name . -o -type d -prune -o -type l -exec rm {} +'

# Create symbolic link to nginx config files in .dev/nginx dir of each project dir.
docker exec -it $CONTAINER_NAME sh -c 'find /var/www/html -maxdepth 4 -path "*/.dev/nginx/*.conf" | sed "s%\(/var/www/html/\)\([^/.]*\)\(/.*\)%\1\2\3 /etc/nginx/conf.d/\2.conf%" | xargs -n 2 ln -s 2> /dev/null'

# Add hostname set as server_name in nginx conf files in each application to /etc/hosts in the container.
# This is required for some tests when phpunit is executed inside of the container.
for filename in `find ${DOCKER_VOLUME_DIR} -maxdepth 4 -path "*/.dev/nginx/*.conf"`; do
  # Use `[[:space:]]` because `\s` does not work on macOS.
  hostname=$(grep -i 'server_name' $filename | sed -E 's/[[:space:]]+server_name[[:space:]]+([^;]+);/\1/')
  docker exec -it $CONTAINER_NAME sh -c "if !(grep -Fqw \"$hostname\" /etc/hosts); then echo -e \"127.0.0.1\t$hostname\" >> /etc/hosts; fi"
done

# Restart http service on container
echo "Restarting php-fpm and nginx..."
docker exec -it $CONTAINER_NAME systemctl restart php-fpm
docker exec -it $CONTAINER_NAME systemctl restart nginx
