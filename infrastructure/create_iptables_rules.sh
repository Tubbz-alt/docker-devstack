#!/bin/bash
GATEWAY=eno1
BRIDGE=br-mgmt-lan
SRC_SBUBNET=10.11.20.0/22
CONT_IP=10.11.23.128
CONT_PORT=80

# forward traffic to and from $SRC_SUBNET
iptables -A FORWARD -i ${BRIDGE} -o ${GATEWAY} -s ${SRC_SUBNET} -j ACCEPT

iptables -A FORWARD -i ${GATEWAY} -o ${BRIDGE} -d ${SRC_SUBNET} -j ACCEPT

iptables -t nat -A POSTROUTING -o ${GATEWAY} -j MASQUERADE

iptables -t nat -A PREROUTING -i ${GATEWAY} -p tcp --dport ${CONT_PORT} \
        -j DNAT --to ${CONT_IP}:${CONT_PORT}

iptables -A FORWARD -i ${GATEWAY} -p tcp --dport ${CONT_PORT} -d ${CONT_IP} -j ACCEPT


