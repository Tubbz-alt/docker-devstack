#!/bin/bash
HOMEDIR="/home/stack"
DEV_DIR="${HOMEDIR}/docker-devstack/service/build"
BACK=${HOMEDIR}/backup

sudo -E apt-get install exuberant-ctags
cd $HOMEDIR || exit

# set up docker-devstack (development)
[ ! -d "${HOMEDIR}/docker-devstack/.git" ] && git clone https://github.com/matt-welch/docker-devstack ${HOMEDIR}/docker-devstack

if [ -f ${HOMEDIR}/devstack/stacking.status ]; then
    source ${HOMEDIR}/devstack/openrc/admin demo
    printenv | grep OS_ > openstackrc
    sed -i 's:^OS_:export OS_:' openstackrc
    cp openstackrc ${DEV_DIR}/openstack/
fi

# move files and replace with newer copies
mkdir -p $BACK
for FILE in start.sh restart.sh service.odl.local.conf; do
    OLDFILE=${HOMEDIR}/$FILE
    NEWFILE=${DEV_DIR}/$FILE
    [ -f "$OLDFILE" ] && mv "$OLDFILE" $BACK
    echo "Linking $NEWFILE in $HOMEDIR"
    ln -s $NEWFILE $HOMEDIR/
done

# setup daffy-dotfiles (terminal settings)
[ ! -d "${HOMEDIR}/daffy-dotfiles/.git" ] && git clone https://github.com/matt-welch/daffy-dotfiles ${HOMEDIR}/daffy-dotfiles
cd ${HOMEDIR}/daffy-dotfiles || exit
${HOMEDIR}/daffy-dotfiles/install.sh

cd ${DEV_DIR}/openstack/ || exit

