#!/bin/bash
# file: create_bridge_network.sh
# info: creates a docker bridged network
SUBNET=10.11.20.0/22
DHCP_RANGE=10.11.23.128/25
NET_NAME=net_br_mgmt
docker network create \
    --internal=false --driver=bridge \
    --subnet=${SUBNET} --ip-range=$DHCP_RANGE \
    $NET_NAME

