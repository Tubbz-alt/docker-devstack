#!/bin/bash
NODE=$1
HOMEDIR=/home/stack
echo "[$(date)] Unstacking $NODE"
docker exec -d -u stack $NODE /home/stack/devstack/unstack.sh
echo "[$(date)] Removing logs from $NODE"
docker exec -d $NODE rm -rf /opt/stack/logs/*
echo "[$(date)] Changing ownership of /opt/stack on $NODE"
docker exec -d $NODE chown -R stack:stack /opt/stack/
echo "[$(date)] Removing stacking.status from $NODE"
docker exec -d $NODE rm -rf "$HOMEDIR/devstack/stacking.status"
echo "[$(date)] Stopping $NODE"
docker stop $NODE

