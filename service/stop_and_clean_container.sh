#!/bin/bash
# good things to "clean" before commiting a container

# /home/stack/devstack/unstack.sh
# sudo rm -rf /home/stack/devstack/stacking.status
# sudo rm -rf /opt/stack/logs/*
# sudo find /opt/stack/opendaylight/ -name \*.hprof -delete # remove java core profiler dumps
# sudo find /opt/stack -user root -o -group root -exec chown stack:stack {} \;
function fn_check_container {
    if [ "$container" == "docker" ]; then
        # running in a container, no need to "docker exec"
        DOCKER_EXEC=""
	NODE=$HOSTNAME
    else
        # running in the host, prefix the commands with "docker exec -it -u stack $NODE"
        DOCKER_EXEC="docker exec -d -u stack $NODE"
    fi
}

function fn_unstack {
    echo "[$(date)] Unstacking $NODE"
    eval "$DOCKER_EXEC /home/stack/devstack/unstack.sh"
}

function fn_clean_logs {
    echo "[$(date)] Removing logs from $NODE "
    eval "$DOCKER_EXEC sudo rm -rf /opt/stack/logs/* "
}

function fn_remove_core_dumps {
    echo "[$(date)] Removing profile dumps (*hprof) from $NODE "
    eval "$DOCKER_EXEC sudo find /opt/stack/opendaylight/ -name \*.hprof -delete" # remove java core profiler dumps

}

function fn_remove_ovs_conf_db {
    echo "[$(date)] Removing OVS configuration DB from $NODE "
    eval "$DOCKER_EXEC sudo systemctl stop openvswitch-switch"
    eval "$DOCKER_EXEC sudo rm -rf /etc/openvswitch/conf.db"
}

function fn_set_ownership {
    echo "[$(date)] Changing ownership of /opt/stack on $NODE"
    eval "$DOCKER_EXEC sudo find /opt/stack -user root -o -group root -exec chown stack:stack {} \;"
}

function fn_remove_status_file {
    echo "[$(date)] Removing ${HOMEDIR}/devstack/stacking.status from $NODE"
    eval "$DOCKER_EXEC sudo rm -rf ${HOMEDIR}/devstack/stacking.status"
}

function fn_stop_container {
    echo "[$(date)] Stopping $NODE"
    if [ "$container" == "docker" ]; then
        exit
    else
        docker stop $NODE
    fi
}

NODE=$1
HOMEDIR=/home/stack
fn_check_container
fn_unstack
fn_clean_logs
fn_remove_core_dumps
fn_remove_ovs_conf_db
fn_set_ownership
fn_remove_status_file
fn_stop_container


# vim: set ai et sw=4 sts=4 ts=4 :

