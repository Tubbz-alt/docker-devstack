#!/bin/bash
# file: run_service.sh
# info: spawns a docker service image
# dependencies: assumes proxy variables are defined in the local environment

# image selection
IMAGE_REGISTRY=${IMAGE_REGISTRY:-"matt-registry:4000"}
IMAGE_REPO=${IMAGE_REPO:-s3p/service}
IMAGE_TAG=${IMAGE_TAG:-v0.5x}
IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

# image configuration
NAME=${HOST_NAME:-service-node}
CAPABILITIES="--privileged --cap-add ALL --security-opt apparmor=docker-unconfined "
SYSTEMD_ENABLING=" --tmpfs /run --tmpfs /run/lock --tmpfs /run/uuid --stop-signal=SIGRTMIN+3 "
CGROUP_MOUNT=" -v /sys/fs/cgroup:/sys/fs/cgroup:ro "
MOUNTS="-v /dev:/dev -v /lib/modules:/lib/modules $CGROUP_MOUNT $SYSTEMD_ENABLING "
PORT_MAP_OFFSET=50000
HORIZON_PORT_CONTAINER=80
DLUX_PORT_CONTAINER=8181
VNC_PORT_CONTAINER=6080
EXTRA_PORT_CONTAINER=8000
HORIZON_PORT_HOST=$(( $PORT_MAP_OFFSET + $HORIZON_PORT_CONTAINER ))
DLUX_PORT_HOST=$(( $PORT_MAP_OFFSET + $DLUX_PORT_CONTAINER ))
VNC_PORT_HOST=$(( $PORT_MAP_OFFSET + $VNC_PORT_CONTAINER ))
EXTRA_PORT_HOST=$(( $PORT_MAP_OFFSET + $EXTRA_PORT_CONTAINER ))
PORT_MAP="-p ${HORIZON_PORT_HOST}:${HORIZON_PORT_CONTAINER} \
    -p ${DLUX_PORT_HOST}:${DLUX_PORT_CONTAINER} \
    -p ${VNC_PORT_HOST}:${VNC_PORT_CONTAINER} \
    -p ${EXTRA_PORT_HOST}:${EXTRA_PORT_CONTAINER}"

# Container environment and OpenStack Config
STACK_USER=${STACK_USER:-stack}
STACK_PASS=${STACK_PASS:-stack}
ODL_NETWORK=${ODL_NETWORK:-True}
SERVICE_HOST=${SERVICE_HOST:-10.129.19.2}
NO_PROXY=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.0/8,127.0.0.1,$SERVICE_HOST

echo "Starting up docker container from image ${IMAGE_NAME}"
echo "name: $NAME"
docker run -dit --name ${NAME} --hostname ${NAME} --env TZ=America/Los_Angeles \
    --env JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 --env JAVA_MAX_MEM=16g \
    --env http_proxy=$http_proxy --env https_proxy=$https_proxy \
    --env no_proxy=$NO_PROXY \
    --env ODL_NETWORK=$ODL_NETWORK \
    --env STACK_PASS=$STACK_PASS \
    --env SERVICE_HOST=$SERVICE_HOST \
    --env container=docker \
    $PORT_MAP \
    $MOUNTS \
    $CAPABILITIES \
    $IMAGE_NAME \
    /sbin/init

# connect containers to host bridges (assumes bridges named br_data and br_mgmt exist on the host
../docker/connect_container_to_networks.sh $HOSTNAME 2 service

AUTO_STACK=no
if [[ "$AUTO_STACK" == "no" ]] ; then
    COMMAND='/bin/bash'
else
    COMMAND='/bin/bash -c "/home/stack/start.sh"'
fi
CONTAINER_SHORT_ID=$(docker ps -aqf "name=${NAME}")
echo "Now entering container: $NAME"
docker exec -it -u $STACK_USER $CONTAINER_SHORT_ID "$COMMAND"

