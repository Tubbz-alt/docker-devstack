#!/bin/bash
# file: run_service.sh
# info: spawns a docker service image
# dependencies: assumes proxy variables are defined in the local environment

# image selection
IMAGE_REPO=${IMAGE_REPO:-s3p/service}
IMAGE_TAG=${IMAGE_TAG:-v0.4}
IMAGE_NAME="${IMAGE_REPO}:${IMAGE_TAG}"

# image configuration
NAME=${HOST_NAME:-service-node}
ODL_NETWORK=${ODL_NETWORK:-True}
CAPABILITIES="--privileged --cap-add ALL --security-opt apparmor=docker-unconfined "
SERVICE_HOST=${SERVICE_HOST:-192.168.3.2}
STACK_PASS=${STACK_PASS:-stack}
# define _no_proxy based on the cluster topology
# connecting to ODL requires no_proxy to contain the EXACT IP address of the
# + service node, e.g. 192.168.3.2
_no_proxy=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.0/8,127.0.0.1,$SERVICE_HOST
SYSTEMD_ENABLING=" --tmpfs /run --tmpfs /run/lock --tmpfs /run/uuid --stop-signal=SIGRTMIN+3 "
CGROUP_MOUNT=" -v /sys/fs/cgroup:/sys/fs/cgroup:ro "
MOUNTS="-v /dev:/dev -v /lib/modules:/lib/modules $CGROUP_MOUNT $SYSTEMD_ENABLING "
PORT_MAP_OFFSET=50000
HORIZON_PORT_CONTAINER=80
DLUX_PORT_CONTAINER=8181
VNC_PORT_CONTAINER=6080
HORIZON_PORT_HOST=$(( $PORT_MAP_OFFSET + $HORIZON_PORT_CONTAINER ))
DLUX_PORT_HOST=$(( $PORT_MAP_OFFSET + $DLUX_PORT_CONTAINER ))
VNC_PORT_HOST=$(( $PORT_MAP_OFFSET + $VNC_PORT_CONTAINER ))
PORT_MAP="-p ${HORIZON_PORT_HOST}:${HORIZON_PORT_CONTAINER} -p ${DLUX_PORT_HOST}:${DLUX_PORT_CONTAINER} -p ${VNC_PORT_HOST}:${VNC_PORT_CONTAINER} "
NETWORK_NAME=${NETWORK_NAME:-"overlay-net"}
NETWORK_SETTINGS="--net=$NETWORK_NAME $PORT_MAP"

echo "Starting up docker container from image ${IMAGE_NAME}"
echo "name: $NAME"
docker run -dit --name ${NAME} --hostname ${NAME} --env TZ=America/Los_Angeles \
    --env JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 --env JAVA_MAX_MEM=16g \
    --env http_proxy=$http_proxy --env https_proxy=$https_proxy \
    --env no_proxy=$_no_proxy \
    --env ODL_NETWORK=$ODL_NETWORK \
    --env STACK_PASS=$STACK_PASS \
    --env SERVICE_HOST=$SERVICE_HOST \
    --env container=docker \
    $NETWORK_SETTINGS \
    $MOUNTS \
    $CAPABILITIES \
    $IMAGE_NAME \
    /sbin/init

CONTAINER_SHORT_ID=$(docker ps -aqf "name=${NAME}")
STATUS=$(docker exec -it $CONTAINER_SHORT_ID grep "^State" /proc/1/status)
while ! ( echo $STATUS | grep "sleeping" )  ; do
    echo "Waiting for init system to complete initialization on container $NAME ... "
    STATUS=$(docker exec -it $CONTAINER_SHORT_ID grep "^State" /proc/1/status)
    sleep 1
done

AUTO_STACK=${1:-no}
# passing an argument of "yes" to run_service.sh will auto-stack
if [[ "$AUTO_STACK" == "yes" ]] ; then
    COMMAND='su -c "/home/stack/start.sh" stack'
else
    COMMAND='/bin/bash'
fi
docker exec -it $CONTAINER_SHORT_ID "$COMMAND"

