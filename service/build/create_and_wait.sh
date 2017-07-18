#!/bin/bash
function fn_isodate {
    date "+%Y-%m-%d %H:%M:%S"
}

function fn_print {
    local MESSAGE=$1
    echo "[$(fn_isodate)] $MESSAGE"
}

function fn_wait_for_tenant {
    if [ "$DEBUG" == "off" ] ; then
        TENANT_NAME=$1
        ADDRESSES=""
        SECONDS=0
        while [ -z "$ADDRESSES" ] ; do
            echo "Waiting for \"$TENANT_NAME\" to obtain an IP address..."
            sleep 0.1
            ADDRESSES=$(openstack server show -f value -c addresses ${TENANT_NAME})
            echo $ADDRESSES
        done
        NETWORK_NAME=$(echo $ADDRESSES | cut -d"=" -f 1)
        TENANT_IP=$(echo $ADDRESSES | cut -d"=" -f 2)
        NET_ID=$(openstack network show -f value -c id ${NETWORK_NAME})
        NETNS="qdhcp-${NET_ID}"
        echo "[$(fn_isodate)] $SECONDS s for OpenStack server API to return an IP address for $TENANT_IP"
        echo "Instance: $TENANT_NAME, TENANT_IP: $TENANT_IP, NET_NAME: $NETWORK_NAME, NET_ID: $NET_ID"
        SECONDS=0
        sudo ip netns exec ${NETNS} ping -c 1 -W 1 $TENANT_IP
        while [ "$?" != 0 ] ; do
            sleep 0.1
            sudo ip netns exec ${NETNS} ping -c 1 -W 1 $TENANT_IP > /dev/null
        done
        sudo ip netns exec ${NETNS} ping -c 1 -W 1 $TENANT_IP
        echo "[$(fn_isodate)]  $SECONDS s for OpenStack server  \"$TENANT_IP\" to respond to ping"
        echo
    else
        echo "MOCKUP: waiting for server to obtain an IP..."
        sleep 2
    fi
    echo
}

function fn_create_instance {
    ID="$1"
    PARENT_NODE=$2
    ZONE=""
    SERVER_NAME=foo
    if [ -n "$2" ] ; then
        # specify zone if parent node is supplied
        PARENT_NODE="${2}"
        PARENT_NODE_ID=${PARENT_NODE#compute-}
        SERVER_NAME="tenant-${PARENT_NODE_ID}-${ID}"
        ZONE="--availability-zone nova:${PARENT_NODE}"
    fi
    if [ -z "$(echo $SERVER_LIST | grep $SERVER_NAME)" ] ; then
        echo "[$(fn_isodate)] Creating server instance ${SERVER_NAME} on host ${PARENT_NODE} with flavor ${FLAVOR}"
        if [ "$DEBUG" == "off" ] ; then
            openstack server create --flavor $FLAVOR --security-group $S3P_SEC_GRP_ID \
                --image $IMAGE $ZONE --nic net-id=$NETWORK_ID $SERVER_NAME
        fi
        fn_wait_for_tenant $SERVER_NAME
    else
        echo "[$(fn_isodate)] WARNING: An instance with name \"${SERVER_NAME}\" already exists, skipping"
        if [ "$VALIDATE_EXISTING" == "on" ] ; then
            # ping an existing server
            # openstack server show $SERVER_NAME
            echo
            fn_wait_for_tenant $SERVER_NAME
        fi
    fi
}

function fn_determine_net_index {
    TYPE=modulo_num_networks
    case "$TYPE" in
        modulo_num_networks)
            # network index is modulo num_networks
            NETWORK_INDEX=$(( $COMP_ID % $NUM_NETWORKS ))
            ;;
        one_per_physhost)
            # one network per physical host
            NETWORK_INDEX=$HOST_ID
            ;;
        one_net)
            # one network - full mesh
            NETWORK_INDEX=0
    esac
}

function fn_attach_to_router {
    local sub_id=$1
    fn_print "Adding router interface from $ROUTER_NAME to subnet $sub_id"
    # usage: openstack router add subnet [-h] <router> <subnet>

    # Add a subnet to a router

    # positional arguments:
    #   <router>    Router to which subnet will be added (name or ID)
    #     <subnet>    Subnet to be added (name or ID)
    openstack router add subnet $ROUTER_ID $sub_id
}

function fn_create_network_and_subnet {
    local NET_NAME=$1
    local NET_IX=$2
    if [ -z "$(echo $NETWORK_LIST | grep $NET_NAME)" ] ; then
        # network does not yet exist - create it and subnet
        if [ "$DEBUG" == "off" ] ; then
            echo "[$(fn_isodate)] Creating network \"$NET_NAME\" for project \"$PROJECT_NAME\""
            NETWORK_ID=$(openstack network create -c id -f value --project $PROJECT_NAME \
                --enable --no-share $NET_NAME)
            if [ -z $NETWORK_ID ] ; then
                echo "ERROR: OpenStack failed to create network \"$NET_NAME\"."
                exit
            else
                NETWORK_LIST="$NETWORK_LIST $NET_NAME"
                echo "Networks: $NETWORK_LIST"
                SUBNET_NAME="${NET_NAME}-sub"
                echo "[$(fn_isodate)] Creating subnet \"$SUBNET_NAME\" for network \"$NET_NAME\""
                SUBNET_ID=$(openstack subnet create -c id -f value --project $PROJECT_NAME \
                    --subnet-range 10.0.${NET_IX}.0/24 \
                    --allocation-pool start=10.0.${NET_IX}.10,end=10.0.${NET_IX}.250 \
                    --ip-version 4 --dhcp --network $NETWORK_ID \
                    $SUBNET_NAME)
                if [ -z $SUBNET_ID ] ; then
                    echo "ERROR: OpenStack failed to create subnet \"$SUBNET_NAME\"."
                    exit
                else
                    SUBNET_IX=$(( $SUBNET_IX + 1 ))
                    SUBNET_LIST="$SUBNET_LIST $SUBNET_NAME"
                    fn_attach_to_router $SUBNET_ID
                    echo "Subnets: $SUBNET_LIST"
                fi
            fi
        else
            # don't create anything
            NETWORK_ID=mock
            SUBNET_ID=mock-sub
        fi
    else
        # network and subnet already exist - do nothing
        echo "WARNING: Network with name $NET_NAME already exists"
        NETWORK_ID=$(openstack network show -f value -c id $NET_NAME )
        echo -e "\n[$(fn_isodate)] INFO: Using network $NET_NAME (id: $NET_ID) for instance "
    fi
}

function fn_set_quotas {
    MAX_INSTANCES=200
    MAX_CORES=${MAX_INSTANCES}
    MAX_NETWORKS=400
    PORTS_PER_NETWORK=4
    SUBNETS_PER_NETWORK=2
    MAX_PORTS=$(( $MAX_NETWORKS * $PORTS_PER_NETWORK ))
    MAX_SUBNETS=$(( $MAX_NETWORKS * $SUBNETS_PER_NETWORK ))

    if [ "$DEBUG" == "off" ] ; then
        echo "[$(fn_isodate)] Setting OpenStack quotas..."
        openstack quota set --instances $MAX_PORTS --cores $MAX_CORES \
            --networks $MAX_NETWORKS --subnets $MAX_SUBNETS \
            --ports $MAX_PORTS --floating-ips $MAX_INSTANCES \
            $PROJECT_NAME
    fi
}

function fn_create_router {
    :
}

function fn_create_security_group {
    local SEC_GRP_NAME=$1
    local SEC_GRP_ID=$(openstack security group show -f value -c id $SEC_GRP_NAME)
    echo SEC_GRP_ID = $SEC_GRP_ID
    if [ -z "$SEC_GRP_ID" ] ; then
        echo "[$(fn_isodate)] Security group ($SEC_GRP_NAME) does not yet exist."
        echo "[$(fn_isodate)] Creating $SEC_GRP_NAME and adding SSH, ICMP rules."
        S3P_SEC_GRP_ID=$(openstack security group create -f value -c id \
            --project $PROJECT_NAME \
            --description "S3P Sec group with SSH + ICMP rules" \
            $SEC_GRP_NAME)
        # allow SSH
        openstack security group rule create --ingress $SEC_GRP_ID --protocol tcp \
            --dst-port 22:22 --src-ip 0.0.0.0/0
        openstack security group rule create --egress $SEC_GRP_ID --protocol tcp -\
            -dst-port 22:22 --src-ip 0.0.0.0/0
        #allow ping
        openstack security group rule create --ingress --protocol ICMP $SEC_GRP_ID
        openstack security group rule create --egress --protocol ICMP $SEC_GRP_ID
        openstack security group show $SEC_GRP_NAME
    else
        S3P_SEC_GRP_ID=$SEC_GRP_ID
    fi
}


function fn_delete_all_instances {
    for TENANT in $(openstack server list -f value -c Name | grep "$S3P_TENANT_PREFIX"); do
        echo "[$(fn_isodate)] Deleting server $TENANT"
        openstack server delete $TENANT
    done
}

function fn_delete_all_networks {
    for NET in $(openstack network list -f value -c Name | grep "$S3P_NET_PREFIX"); do
        echo "[$(fn_isodate)] Deleting network $NET"
        openstack network delete $NET
    done
}

# defaults:
FLAVOR="cirros256"
IMAGE="cirros-0.3.4-x86_64-uec"
PROJECT_NAME=demo
PROJECT_ID=$(openstack project show -f value -c id $PROJECT_NAME)
DEBUG=off
VALIDATE_EXISTING=on
S3P_SEC_GRP_NAME="s3p_secgrp"
S3P_NET_PREFIX="s3p-net-"
S3P_TENANT_PREFIX="tenant-"
SERVERS_PER_HOST=1
NUM_NETWORKS=6
SUBNET_IX=1
# NETWORK_NAME=private
ATTACH_TO_ROUTER=True
# Main()
if [ "$1" == cleanup ] ; then
    echo "WARNING: You are about to delete all instances matching name \"$S3P_TENANT_PREFIX\" and all networks matching \"$S3P_NET_PREFIX\"."
    read -p "Are you sure you want to proceed? [y/N]: " -i 1 input
    if [ "$input" == "y" ]; then
        fn_delete_all_instances
        fn_delete_all_networks
    else
        echo "OpenStack delete operation aborted."
    fi
else
    # NETWORK_ID=$(openstack network show -f value -c id  $NETWORK_NAME)
    # NETNS=$(ip netns ls | grep $NETWORK_ID)

    fn_set_quotas
    fn_create_security_group $S3P_SEC_GRP_NAME
    if [ "$ATTACH_TO_ROUTER" == "True" ] ; then
        echo "Fetching router ID"
        ROUTER_ID=$(openstack router list -f value | grep $PROJECT_ID | cut -d' ' -f 1)
        ROUTER_NAME=$(openstack router show -f value -c name $ROUTER_ID)
    fi

    NETWORK_LIST="$(openstack network list -f value -c Name)"
    SUBNET_LIST="$(openstack subnet list -f value -c Name)"
    SERVER_LIST="$(openstack server list -f value -c Name)"
    # hypervisor list with newest cluster members first
    HYPERVISOR_LIST_NEW_FIRST=$(openstack compute service list --service nova-compute  -c Host -c Status -c ID -f value | grep enabled | sort -rg | cut -d ' ' -f 2)
    HYPERVISOR_LIST=$HYPERVISOR_LIST_NEW_FIRST
    # # hypervisor list with oldest members of cluster sorted first
    # HYPERVISOR_LIST=$(openstack compute service list --service nova-compute -f value -c Host -c Status | grep enabled | cut -d ' ' -f 1)
    for (( TENANT_INDEX=1; TENANT_INDEX<=${SERVERS_PER_HOST} ; TENANT_INDEX++ )); do
        for HYPERVISOR in $HYPERVISOR_LIST; do
            fn_print "Checking tenant index #${TENANT_INDEX} on hypervisor $HYPERVISOR..."
            # compute node identifier (e.g. compute-23-11: NODE_ID=23-11
            NODE_ID=${HYPERVISOR##compute-}
            # index of compute node on host (e.g. compute-23-11: COMP_ID=11
            COMP_ID=${HYPERVISOR#compute-*-}
            # Physical server ID (e.g. compute-23-11: HOST_ID=23
            HOST_ID=${NODE_ID%-*}
            fn_determine_net_index
            # note: the network name may be static or determined otherwise here
            NETWORK_NAME="${S3P_NET_PREFIX}${NETWORK_INDEX}"
            #if [ "$TENANT_INDEX" == "1" -a "$COMP_ID" == "11" ] ; then
            fn_create_network_and_subnet $NETWORK_NAME $NETWORK_INDEX
            fn_create_instance $TENANT_INDEX $HYPERVISOR
        done
    done
fi

# vim: set et sw=4 ts=4 ai :

