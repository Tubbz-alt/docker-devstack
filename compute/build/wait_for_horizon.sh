#/bin/bash
PROJECT_NAME=demo
if [ -z "$OS_AUTH_URL" -o -z "$(echo $OS_AUTH_URL | grep "$SERVICE_HOST")" ]; then
    source /home/stack/devstack/openrc admin $PROJECT_NAME
fi

while ! wget http://$SERVICE_HOST/dashboard 2>/dev/null
do
    echo "[$(date)] Waiting for horizon to become active..."
    sleep 5
done
cd /home/stack

/home/stack/restart.sh

