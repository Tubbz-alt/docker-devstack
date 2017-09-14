FROM        mattw4/s3p-systemd:v0.2
MAINTAINER  OpenDaylight Integration Project Team <integration-dev@lists.opendaylight.org>

ENV     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        DEBIAN_FRONTEND=noninteractive \
        container=docker

# Install devstack dependencies
RUN     apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        inetutils-ping \
        iproute2 \
        iptables \
        lsb-release \
        openssh-server \
        openvswitch-common \
        openvswitch-switch \
        sudo \
        vim && \
        rm -rf /var/lib/apt/lists/*

# remove nologin to allow ssh - yes, I know, it's a terrible idea
RUN     rm -rf /var/run/nologin

# Add stack user
RUN     groupadd stack && \
        useradd -g stack -s /bin/bash -m stack && \
        echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# get devstack
RUN     git clone https://git.openstack.org/openstack-dev/devstack /home/stack/devstack

# copy local.conf & scripts
COPY    compute.odl.local.conf /home/stack/compute.odl.local.conf
COPY    wait_for_networks.sh /home/stack/wait_for_networks.sh
COPY    start.sh /home/stack/start.sh
COPY    restart.sh /home/stack/restart.sh
RUN     chown -R stack:stack /home/stack && \
        chmod 766 /home/stack/start.sh && \
        chmod 766 /home/stack/restart.sh && \
        chmod 766 /home/stack/wait_for_networks.sh

WORKDIR /home/stack

LABEL nodetype="compute" version="v0.5" ODL_RELEASE="carbon-snapshot-0.6.1"

# vim: set ft=dockerfile sw=4 ts=4 :

