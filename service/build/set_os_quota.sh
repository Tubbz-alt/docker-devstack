#!/bin/bash
USER=admin
PROJECT=demo
source /home/stack/devstack/openrc $USER $PROJECT
openstack quota set --cores -1 --instances -1 $PROJECT
