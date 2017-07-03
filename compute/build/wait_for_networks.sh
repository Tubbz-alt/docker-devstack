#/bin/bash
PROJECT_NAME=demo
S3P_NETWORK=private
if [ -z "$OS_AUTH_URL" -o -z "$(echo $OS_AUTH_URL | grep "$SERVICE_HOST")" ]; then
    source /home/stack/devstack/openrc admin $PROJECT_NAME
fi

while ! openstack network show $S3P_NETWORK 2>/dev/null
do
    echo "[$(date)] Waiting for networks to become active..."
    sleep 5
done
cd /home/stack

/home/stack/restart.sh

