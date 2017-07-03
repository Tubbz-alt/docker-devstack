#!/bin/bash

USER=admin
PROJECT=demo
source /home/stack/devstack/openrc $USER $PROJECT
PROJECT_ID=$(openstack project list | grep " demo " | cut -d "|" -f 2 | tr -d " ")
net_id=$(openstack network show private -f shell --prefix net_ | grep "net_id" | grep -o '".*"' | sed 's/"//g')

# create servers
FLAVOR="m1.tiny"
IMAGE="cirros-0.3.4-x86_64-uec"
DEBUG=off

function s3p_create_server {
    if [ -z "$1" ] ; then
        echo "ERROR: A server ID nust be supplied"
    else
        ID="$1"
        SERVER_NAME="tenant-${ID}"
        ZONE=""
        PARENT_NODE="random"
        if [ -n "$2" ] ; then
            # specify zone if parent node is supplied
            PARENT_NODE="${2}"
            PARENT_NODE_ID=${PARENT_NODE#compute-}
            SERVER_NAME="tenant-${PARENT_NODE_ID}-${ID}"
            ZONE="--availability-zone nova:${PARENT_NODE}"
        fi
        echo "[$(date)] Creating server instance ${SERVER_NAME} on host ${PARENT_NODE} with flavor ${FLAVOR}"
        if [ "$DEBUG" == "off" ] ; then
            openstack server create --flavor $FLAVOR --image $IMAGE $ZONE --nic net-id=$net_id $SERVER_NAME
        fi
    fi
}

function create_security_group_rules {
    SEC_GRP_ID=$(openstack security group list | grep "$PROJECT_ID" | cut -d "|" -f 2 | tr -d ' ')
    # allow SSH
    openstack security group rule create --ingress $SEC_GRP_ID --protocol tcp --dst-port 22:22 --src-ip 0.0.0.0/0
    openstack security group rule create --egress $SEC_GRP_ID --protocol tcp --dst-port 22:22 --src-ip 0.0.0.0/0
    #allow ping
    openstack security group rule create --ingress --protocol ICMP $SEC_GRP_ID
    openstack security group rule create --egress --protocol ICMP $SEC_GRP_ID
}

function s3p_nsenter {
    # usage: nsenter [ IPNETNS ]
    if [ -z "$1" ] ; then
        NETNS=$(ip netns ls | grep dhcp )
        echo "No netns supplied as argument, using NETNS=$NETNS"
    else
        NETNS=$1
        echo "A netns was supplied as argument, using NETNS=$NETNS"
    fi
    sudo ip netns exec $NETNS /bin/bash
}

SERVERS_PER_HOST=2
if [[ "$0" == *"bash"* ]] ; then
    echo "Functions available in /home/stack/create_servers.sh:"
    grep function /home/stack/create_servers.sh | cut -d ' ' -f2
else
    # ALL_SERVERS=$(openstack openstack hypervisor list -f csv | cut -d '' -f2 )
    # echo $ALL_SERVERS
    for hypervisor in $(openstack hypervisor list -f value | cut -d ' ' -f2 ) ; do
        # openstack hypervisor show $hypervisor
        HOST_ZONE="${hypervisor}"
        for (( TENANT_INDEX=2; TENANT_INDEX<=${SERVERS_PER_HOST} ; TENANT_INDEX++ )); do
            s3p_create_server $TENANT_INDEX $HOST_ZONE
            if [ "$DEBUG" == "off" ] ; then
                echo "Sleeping for 60 seconds to give time for tenants to spin up"
                sleep 60
            fi
        done
    done
    # HOST_ID="n28"

    # ID=1
    # HOST_ZONE="compute-${HOST_ID}-001"
    # s3p_create_server "$(printf "%.3d" $ID)"   # "$HOST_ZONE"
    # openstack server show $SERVER_NAME

    # ID=2
    # HOST_ZONE="compute-${HOST_ID}-002"
    # s3p_create_server "$(printf "%.3d" $ID)"   # "$HOST_ZONE"
    # openstack server show $SERVER_NAME
    # #ID=$(( $ID + 1 ))
    # #s3p_create_server "$(printf "%.3d" $ID)" "compute-o17-002"
fi

# vim: set et sw=4 ts=4 :

