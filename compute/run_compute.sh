#!/bin/bash
# file: run_compute.sh
# info: spawns a docker compute image
# dependencies: consumes proxy variables if defined in the local environment
# + To connect to an OpenStack service node, it must first be running.
# + Compute host image must also be available locally or in a registry.

# image selection
IMAGE_REPO=${IMAGE_REPO:-ss3p/compute}
IMAGE_TAG=${IMAGE_TAG:-v0.4}
IMAGE_NAME="${IMAGE_REPO}:${IMAGE_TAG}"

# image configuration
NAME=${HOST_NAME:-compute-001}
ODL_NETWORK=${ODL_NETWORK:-True}
# when running on a RHEL-derivative host, use "--security-opt seccomp=unconfined"
CAPABILITIES="--privileged --cap-add ALL --security-opt apparmor=docker-unconfined "
SYSTEMD_ENABLING=" --tmpfs /run --tmpfs /run/lock --tmpfs /run/uuid --stop-signal=SIGRTMIN+3 "
CGROUP_MOUNT=" -v /sys/fs/cgroup:/sys/fs/cgroup:ro "
MOUNTS="-v /dev:/dev -v /lib/modules:/lib/modules $CGROUP_MOUNT $SYSTEMD_ENABLING "
STACK_PASS=${STACK_PASS:-stack}
# default SERVICE_HOST, based on openstack. This may be overridden.
SERVICE_HOST=${SERVICE_HOST:-192.168.3.2}
# define _no_proxy based on the cluster topology
_no_proxy=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.1,127.0.0.0/8,$SERVICE_HOST
PORT_MAP=""
NETWORK_NAME=${NETWORK_NAME:-"overlay-net"}
NETWORK_SETTINGS="--net=$NETWORK_NAME $PORT_MAP"

echo "Starting up docker container from image ${IMAGE_NAME}"
echo "name: $NAME"
docker run -dit --name ${NAME} --hostname ${NAME} --env TZ=America/Los_Angeles \
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
# passing an argument of "yes" to run_compute.sh will auto-stack
if [[ "$AUTO_STACK" == "yes" ]] ; then
    COMMAND='su -c "/home/stack/start.sh" stack'
else
    COMMAND='/bin/bash'
fi
docker exec -it $CONTAINER_SHORT_ID "$COMMAND"

