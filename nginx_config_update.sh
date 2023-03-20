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
echo "Deleting broken symbolic links."
docker exec -it $CONTAINER_NAME sh -c 'cd /etc/nginx/conf.d && find -L . -name . -o -type d -prune -o -type l -exec rm {} +'

# Create symbolic link to nginx config files in .dev/nginx dir of each project dir.
echo "Creating symbolic link to nginx config files."
docker exec -it $CONTAINER_NAME sh -c 'find /var/www/html -maxdepth 4 -name "node_modules" -prune -o -name "vendor" -prune -o -name ".git" -prune -o -name "storage" -prune -o -path "*/.dev/nginx/*.conf" -print | sed "s%\(/var/www/html/\)\([^/.]*\)\(/.*\)%\1\2\3 /etc/nginx/conf.d/\2.conf%" | xargs -n 2 ln -s 2> /dev/null'

# Create symbolic link to nginx config files in .dev/php dir of each project dir.
echo "Creating symbolic link to PHP config files."
docker exec -it $CONTAINER_NAME sh -c 'find /var/www/html -maxdepth 4 -name "node_modules" -prune -o -name "vendor" -prune -o -name ".git" -prune -o -name "storage" -prune -o -path "*/.dev/php/*.ini" -print | sed "s%\(/var/www/html/\)\([^/.]*\)\(/.*\)%\1\2\3 /etc/php.d/90-\2.ini%" | xargs -n 2 ln -s 2> /dev/null'

# Add hostname set as server_name in nginx conf files in each application to /etc/hosts in the container.
# This is required for some tests when phpunit is executed inside of the container.
echo "Adding hostnames to /etc/hosts in the container."
for filename in `find ${DOCKER_VOLUME_DIR} -maxdepth 4 -name "node_modules" -prune -o -name "vendor" -prune -o -name ".git" -prune -o -name "storage" -prune -o -path "*/.dev/nginx/*.conf" -print 2>&1 | fgrep -v "Permission denied"`; do
  # Use `[[:space:]]` because `\s` does not work on macOS.
  hostname=$(grep -i 'server_name' $filename | sed -E 's/[[:space:]]+server_name[[:space:]]+([^;]+);/\1/')
  docker exec -it $CONTAINER_NAME sh -c "if !(grep -Fqw \"$hostname\" /etc/hosts); then echo -e \"127.0.0.1\t$hostname\" >> /etc/hosts; fi"
done

# Execute hook script in .dev/php dir of each project dir.
echo "Executing hook script in .dev/php dir."
docker exec -it $CONTAINER_NAME sh -c 'find /var/www/html -maxdepth 3 -name "node_modules" -prune -o -name "vendor" -prune -o -name ".git" -prune -o -name "storage" -prune -o -path "*/.dev/container_hook.sh" -print -exec bash {} \;'

# Restart http service on container
echo "Restarting php-fpm."
docker exec -it $CONTAINER_NAME systemctl restart php-fpm
echo "Restarting nginx."
docker exec -it $CONTAINER_NAME systemctl restart nginx
