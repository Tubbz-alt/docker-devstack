source ./centos.systemd.test.vars

NAME=$SERVICE_HOST_NAME
IMAGE_NAME="centos/systemd:latest"
IMAGE_NAME="s3p/service:centos-systemd"
echo IMAGE=$IMAGE_NAME


docker run -d --name $NAME --hostname $SERVICE_HOST_NAME \
    --env TZ=America/Los_Angeles --env JAVA_HOME=/usr/lib/jvm/java-8-oracle \
    --env JAVA_MAX_MEM=16g --env http_proxy=http://proxy-chain.intel.com:912 \
    --env https_proxy=http://proxy-chain.intel.com:912 \
    --env no_proxy=localhost,10.0.0.0/8,192.168.0.0/16,172.17.0.0/16,127.0.0.0/8,127.0.0.1,10.20.0.2 \
    --env ODL_NETWORK=true --env STACK_PASS=stack --net=overlay-net \
    -p 61080:80 -v /dev:/dev -v /lib/modules:/lib/modules \
    --privileged --cap-add ALL --cap-add NET_ADMIN --cap-add NET_RAW \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    $IMAGE_NAME

# docker exec -it $NAME systemctl status

