#!/bin/bash
function fn_isodate {
    date "+%Y-%m-%d %H:%M:%S"
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
            openstack server create --flavor $FLAVOR --security-group $S3P_SEC_GRP \
                --image $IMAGE $ZONE --nic net-id=$NETWORK_ID $SERVER_NAME
        fi
        fn_wait_for_tenant $SERVER_NAME
    else
        echo "[$(fn_isodate)] WARNING: An instance with name \"${SERVER_NAME}\" already exists, skipping"
        if [ "$VALIDATE_EXISTING" == "on" ] ; then
            # ping an existing server
            openstack server show $SERVER_NAME
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

function fn_create_network_and_subnet {
    NET_NAME=$1
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
                    --subnet-range 10.0.${SUBNET_IX}.0/24 \
                    --allocation-pool start=10.0.${SUBNET_IX}.10,end=10.0.${SUBNET_IX}.250 \
                    --ip-version 4 --dhcp --network $NETWORK_ID \
                    $SUBNET_NAME)
                if [ -z $SUBNET_ID ] ; then
                    echo "ERROR: OpenStack failed to create subnet \"$SUBNET_NAME\"."
                    exit
                else
                    SUBNET_IX=$(( $SUBNET_IX + 1 ))
                    SUBNET_LIST="$SUBNET_LIST $SUBNET_NAME"
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
    :
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
DEBUG=off
VALIDATE_EXISTING=on
S3P_SEC_GRP="s3p_secgrp"
S3P_NET_PREFIX="s3p-net-"
S3P_TENANT_PREFIX="tenant-"
SERVERS_PER_HOST=2
NUM_NETWORKS=10
SUBNET_IX=1
NETWORK_NAME=private

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
	NETWORK_ID=$(openstack network show -f value -c id  $NETWORK_NAME)
	NETNS=$(ip netns ls | grep $NETWORK_ID)

	fn_set_quotas
	fn_create_security_group
    NETWORK_LIST="$(openstack network list -f value -c Name)"
    SUBNET_LIST="$(openstack subnet list -f value -c Name)"
    SERVER_LIST="$(openstack server list -f value -c Name)"
    HYPERVISOR_LIST=$(openstack compute service list --service nova-compute -f value -c Host -c Status | grep enabled | cut -d ' ' -f 1)
	for (( TENANT_INDEX=1; TENANT_INDEX<=${SERVERS_PER_HOST} ; TENANT_INDEX++ )); do
        for HYPERVISOR in $HYPERVISOR_LIST; do
			if [ "$(openstack hypervisor show -f value -c status $HYPERVISOR)" == "enabled" ]; then
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
				fn_create_network_and_subnet $NETWORK_NAME
				fn_create_instance $TENANT_INDEX $HYPERVISOR
			else
				echo -e "\n[$(fn_isodate)] WARNING: hypervisor \"$HYPERVISOR\" is disabled: skipping.\n"
			fi
		done
	done
fi

# vim: set et sw=4 ts=4 ai :

