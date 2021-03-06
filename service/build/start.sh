#!/bin/sh
# On docker run, Env Variables "STACK_PASS & SERVICE_HOST" should be set using -e
#  example 'docker run -e "STACK_PASS=stack" -e "SERVICE_HOST=192.168.0.5" compute'
# or overided below by uncommenting:
set -o nounset # throw an error if a variable is unset to prevent unexpected behaviors
STACK_PASS="stack"
SERVICE_HOST=${SERVICE_HOST:-10.129.20.2}
# ODL_NETWORK should be set in the 'docker run' script
ODL_NETWORK=${ODL_NETWORK}
DEVSTACK_HOME="/home/stack/devstack"
CONF_PATH=$DEVSTACK_HOME/local.conf
BRANCH_NAME=stable/newton
TAG_NAME="origin/${BRANCH_NAME}"

#Set Nameserver to google
[ -z "$(grep "8.8.8.8" /etc/resolv.conf )" ] && echo nameserver 8.8.8.8 | sudo tee -a /etc/resolv.conf

# change the stack user password
echo "stack:$STACK_PASS" | sudo chpasswd

# get container IP
export mgmt_veth_name="ethmgmt"
export data_veth_name="ethdata"
ip=`/sbin/ip -o -4 addr list $mgmt_veth_name | awk '{print $4}' | cut -d/ -f1`
[ -z "$( echo $no_proxy | grep "$(hostname)" )" ] && export no_proxy="${no_proxy},$(hostname)"
[ -z "$( echo $no_proxy | grep "${ip}" )" ] && export no_proxy="${no_proxy},${ip}"
[ -z "$( echo $no_proxy | grep "${SERVICE_HOST}" )" ] && export no_proxy="${no_proxy},${SERVICE_HOST}"

# fix address binding issue in mysql
sudo sed -i 's:^bind-address.*:#&:' /etc/mysql/my.cnf

# allow services to start
sudo sed -i 's:^exit .*:exit 0:' /usr/sbin/policy-rc.d

# remove OVS db (for case of restacking a node to regenerate UUID)
sudo systemctl stop openvswitch-switch.service
sudo rm -rf /etc/openvswitch/conf.db
sudo systemctl start openvswitch-switch.service

# remove any dead screen sessions from previous stacking
screen -wipe

# set the correct branch in devstack
cd $DEVSTACK_HOME
[ -z "$(git branch -a | grep "* ${BRANCH_NAME}")" ] && \
	git fetch && \
	git checkout -b ${BRANCH_NAME} -t ${TAG_NAME}

# Configure local.conf
# copy local.conf into devstack and customize, based on environment:
SRC_CONF=service.odl.local.conf
if [ "$ODL_NETWORK" = "False" ] ; then
    SRC_CONF=service.ovs.local.conf
fi
cp /home/stack/$SRC_CONF $CONF_PATH

# update the ip of this host
sed -i "s:\(HOST_IP=\).*:\1${ip}:" $CONF_PATH
sed -i "s:\(SERVICE_HOST=\).*:\1${ip}:" $CONF_PATH

# begin stacking
cd $DEVSTACK_HOME
$DEVSTACK_HOME/stack.sh

# write a marker file to indicate successful stacking
if [ $? = 0 ] ; then
    echo "$(hostname) stacking successful at $(date)" >> stacking.status
    /home/stack/devstack/tools/info.sh >> stacking.status
    source $DEVSTACK_HOME/openrc admin demo
    printenv | grep OS_ | sed 's/^OS_/export OS_/g' > /home/stack/openstackrc
    sed -i "s/^#.*\(OFFLINE.*$\)/\1/" /home/stack/$SRC_CONF
    sed -i "s/^#.*\(RECLONE.*$\)/\1/" /home/stack/$SRC_CONF
fi

# vim: set et ts=4 sw=4 :

