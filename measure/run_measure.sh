#!/bin/bash
# file: run_measure.sh
# info: spawns a docker measurement image

# image selection
IMAGE_REGISTRY=${IMAGE_REGISTRY:-"matt-registry:4000"}
IMAGE_REPO=${IMAGE_REPO:-"s3p/measure"}
IMAGE_TAG=${IMAGE_TAG:-"v0.1"}
IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

# image configuration
NAME=${HOST_NAME:-measure-node}
ODL_NETWORK=${ODL_NETWORK:-True}
CAPABILITIES="--privileged --cap-add ALL --security-opt apparmor=docker-unconfined "
SYSTEMD_ENABLING="--stop-signal=SIGRTMIN+3 "
CGROUP_MOUNT=" -v /sys/fs/cgroup:/sys/fs/cgroup:ro "
MOUNTS="-v /dev:/dev -v /lib/modules:/lib/modules $CGROUP_MOUNT $SYSTEMD_ENABLING "
STACK_PASS=${STACK_PASS:-stack}
SERVICE_HOST=${SERVICE_HOST:-192.168.3.2}
_no_proxy=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.1,127.0.0.0/8,$SERVICE_HOST

docker run -dit --name ${NAME} --hostname ${NAME} \
    --env http_proxy=$http_proxy --env https_proxy=$https_proxy \
    --env no_proxy=$_no_proxy \
    --env ODL_NETWORK=$ODL_NETWORK \
    --env SERVICE_HOST=$SERVICE_HOST \
    --env container=docker \
    $MOUNTS \
    $CAPABILITIES \
    $IMAGE_NAME \
    /sbin/init

COMMAND="/bin/bash"
CONTAINER_SHORT_ID=$(docker ps -aqf "name=${NAME}")
docker exec -it -u stack $CONTAINER_SHORT_ID "$COMMAND"

