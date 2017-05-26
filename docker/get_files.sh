#!/bin/bash
CONTAINER_ID=$1
if [  -z "${CONTAINER_ID}" ] ; then 
    echo -e "ERROR: you must specify a \"CONTAINER ID\" or container \"NAME\" from the following: \n"
    docker ps -a
else
    if [ -n "$(docker ps -a | grep ${CONTAINER_ID})" ] ; then 
        NAME="${CONTAINER_ID}.$(hostname).$(date +"%Y%m%dT%H%M%S")"
        TARBALL=/home/stack/${NAME}.tar.gz
        echo "Creating tarball"
        docker exec -it $CONTAINER_ID tar --exclude *tar.gz --exclude /home/stack/docker-devstack --exclude /home/stack/devstack -cf ${TARBALL} /home/stack
        echo "Making directory $NAME"
        mkdir ${NAME}
        echo "Copying tarball ..."
        docker cp ${CONTAINER_ID}:${TARBALL} ./${NAME}/
        echo "cd $NAME"
        cd ./${NAME}/
    else
        echo "ERROR: \"${CONTAINER_ID}\" is not a valid container..."
    fi
fi
