#!/bin/bash
# file: reset_adapter_ip.sh

# TODO: figure out this lise automatically, maybe from "physdevs" ip link group, maybe physical adapters listed under /sys/class/net
declare -a DEVLIST=("eno1" "eno2" "eno3" "eno4" )
N_devs=${#DEVLIST[*]}
startIX=1 # skip 1st adapter (DHCP)
HOSTNAME=$(hostname)
for(( i=${startIX}; i<${N_devs}; i++ )); do
    _dev=${DEVLIST[$i]}

    IP=$(./lookup_IP_addr.py $(hostname) $i)
    echo Setting adapter $_dev to IP $IP
    ip a flush $_dev
    ip a a ${IP} dev $_dev
    ip link set dev $_dev up
done

# vim: set et ts=4 sw=4 :

