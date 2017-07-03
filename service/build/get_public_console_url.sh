#!/bin/bash
DOCKER_BRIDGE_SUBNET="172/8"
DOCKER_BRIDGE_IP="172.17.0.1" #$(ip -o -4 a s to ${DOCKER_BRIDGE_SUBNET} | awk '{print $4}' | cut -d '/' -f 1 )
# echo $DOCKER_BRIDGE_IP
PUBLIC_SUBNET="10.166/16"
PHYS_HOST_PUB_IP="$(ssh root@${DOCKER_BRIDGE_IP} ip -o -4 a s to $PUBLIC_SUBNET | awk '{print $4}' | cut -d '/' -f 1 )"
# echo $PHYS_HOST_PUB_IP
NOVNC_PROXY_PORT="$(grep novncproxy_port /home/stack/devstack/local.conf | cut -d '=' -f 2 | tr -d " ")"
MAPPED_PORT=$(( $NOVNC_PROXY_PORT + 50000 ))
# echo $MAPPED_PORT
if [ -z "$(printenv OS_PASSWORD)" ] ; then
	source /home/stack/devstack/openrc admin demo
fi

if [ -z "$1" ] ; then
	echo -e "\nNo instance ID specified, try again with the form ./get_public_console_url.sh <instance ID>"
	echo -e "\nAvailable OpenStack servers: "
	openstack server list
	echo
else
	INSTANCE_ID="$1"
	BASE_URL=$(openstack console url show -f value -c url $INSTANCE_ID | sed "s/${SERVICE_HOST}/${PHYS_HOST_PUB_IP}/g" | sed "s|:${NOVNC_PROXY_PORT}/|:${MAPPED_PORT}/|g")
	URL_TITLE="&title=${INSTANCE_ID}"
	URL="${BASE_URL}${URL_TITLE}"
	echo -e "\nThe VNC console for instance $INSTANCE_ID is available at \n${URL}\n"
fi
