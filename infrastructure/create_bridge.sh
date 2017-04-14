#!/bin/bash
# file: create_bridge.sh
# info: creates a linux bridge and binds a physical adapter to it
BR_NAME=${1:-br_mgmt}
IF_10GB_0=${2:-eno3}
ADAPTER=$IF_10GB_0
IPADDR=$(ip -o -4 addr show dev $ADAPTER | awk '{print $4}')

ip addr flush $ADAPTER
ip link set $ADAPTER up
ip link set $ADAPTER promisc on
brctl addbr $BR_NAME
brctl addif $BR_NAME $ADAPTER
ip addr add $IPADDR dev $BR_NAME
#brctl showmacs $BR_NAME
ip link set $BR_NAME up

