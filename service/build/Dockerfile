FROM        mattw4/s3p-systemd:v0.2
MAINTAINER  OpenDaylight Integration Project Team <integration-dev@lists.opendaylight.org>

ENV     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        DEBIAN_FRONTEND=noninteractive \
        container=docker

# Install devstack dependencies
RUN     apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        iproute2 \
        iptables \
        lsb-release \
        net-tools \
        python \
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

# get docker-devstack for tools
RUN     git clone https://github.com/matt-welch/docker-devstack /home/stack/docker-devstack

# copy local.conf & scripts
COPY    service.odl.local.conf /home/stack/service.odl.local.conf
COPY    start.sh /home/stack/start.sh
COPY    restart.sh /home/stack/restart.sh
COPY    openstack/create_and_wait.sh /home/stack/create_and_wait.sh
RUN     chown -R stack:stack /home/stack && \
        chmod 766 /home/stack/*.sh 

WORKDIR /home/stack

# vim: set ft=dockerfile sw=4 ts=4 :

