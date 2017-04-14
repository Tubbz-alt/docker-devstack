#!/bin/bash
# file: remove_bridge.sh
# info: removes the bridge and re-establishes the physical adapter
BR_NAME=${1:-br_mgmt}
IF_10GB_0=${2:-eno3}
ADAPTER=$IF_10GB_0

IPADDR=$(ip -o -4 addr show dev $BR_NAME | awk '{print $4}')

ip addr flush $BR_NAME
ip link set $BR_NAME down
brctl delif $BR_NAME $ADAPTER
brctl delbr $BR_NAME
ip addr add $IPADDR dev $ADAPTER
ip link set $ADAPTER up
ip link set $ADAPTER promisc off

