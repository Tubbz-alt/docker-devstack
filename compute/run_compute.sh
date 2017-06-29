#!/bin/bash
# file: ./run_compute.sh
# info: spawns a docker compute image
# dependencies: consumes proxy variables if defined in the local environment
# + To connect to an OpenStack service node, it must first be running.
# + Compute host image must also be available locally or in a registry.

# image selection
IMAGE_REGISTRY=${IMAGE_REGISTRY:-"matt-registry:4000"}
IMAGE_REPO=${IMAGE_REPO:-s3p/compute}
IMAGE_TAG=${IMAGE_TAG:-v0.5}
IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

# image configuration
HOST_ID=${HOST_ID:-99} # should be in the env
COMP_ID=${COMP_ID:-11}
NAME=${CONTAINER_NAME:-compute-${HOST_ID}-${COMP_ID}}
CAPABILITIES="--privileged --cap-add ALL --security-opt apparmor=docker-unconfined "
SYSTEMD_ENABLING=" --tmpfs /run --tmpfs /run/lock --tmpfs /run/uuid --stop-signal=SIGRTMIN+3 "
CGROUP_MOUNT=" -v /sys/fs/cgroup:/sys/fs/cgroup:ro "
MOUNTS="-v /dev:/dev -v /lib/modules:/lib/modules $CGROUP_MOUNT $SYSTEMD_ENABLING "

# Container environment and OpenStack Config
STACK_USER=${STACK_USER:-stack}
STACK_PASS=${STACK_PASS:-stack}
ODL_NETWORK=${ODL_NETWORK:-True}
SERVICE_HOST=${SERVICE_HOST:-10.129.19.2}
NO_PROXY=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.1,127.0.0.0/8,$SERVICE_HOST

docker run -dit --name ${NAME} --hostname ${NAME} --env TZ=America/Los_Angeles \
    --env http_proxy=$http_proxy --env https_proxy=$https_proxy \
    --env no_proxy=$NO_PROXY \
    --env ODL_NETWORK=$ODL_NETWORK \
    --env STACK_PASS=$STACK_PASS \
    --env SERVICE_HOST=$SERVICE_HOST \
    --env container=docker \
    $MOUNTS \
    $CAPABILITIES \
    $IMAGE_NAME \
    /sbin/init

# connect containers to host bridges (assumes bridges named br_data and br_mgmt exist on the host
../docker/connect_container_to_networks.sh $HOSTNAME $COMP_ID compute

AUTO_STACK=no
if [[ "$AUTO_STACK" == "no" ]] ; then
    COMMAND='/bin/bash'
else
    COMMAND='/bin/bash -c "/home/stack/start.sh"'
fi
CONTAINER_SHORT_ID=$(docker ps -aqf "name=${NAME}")
echo "Now entering container: $NAME"
docker exec -it -u $STACK_USER $CONTAINER_SHORT_ID "$COMMAND"

