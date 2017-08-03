#!/bin/bash
HOMEDIR="/home/stack"
DEV_DIR="${HOMEDIR}/docker-devstack/service/build"
BACK=${HOMEDIR}/backup

sudo -E apt-get install exuberant-ctags
cd $HOMEDIR || exit

# set up docker-devstack (development)
[ ! -d 'docker-devstack/.git' ] && git clone https://github.com/matt-welch/docker-devstack
source ${HOMEDIR}/devstack/openrc/admin demo
printenv | grep OS_ > openstackrc
sed -i 's:^OS_:export OS_:' openstackrc
cp openstackrc ${DEV_DIR}/openstack/

# move files and replace with newer copies
mkdir -p $BACK
FILE='start.sh'
OLDFILE=${HOMEDIR}/$FILE
NEWFILE=${DEV_DIR}/$FILE
[ -f "$OLDFILE" ] && mv "$OLDFILE" $BACK
ln -s $NEWFILE $HOMEDIR/
FILE='restart.sh'
OLDFILE=${HOMEDIR}/$FILE
NEWFILE=${DEV_DIR}/$FILE
[ -f "$OLDFILE" ] && mv "$OLDFILE" $BACK
ln -s $NEWFILE $HOMEDIR/

# setup daffy-dotfiles (terminal settings)
[ ! -d 'daffy-dotfiles/.git' ] && git clone https://github.com/matt-welch/daffy-dotfiles
cd ${HOMEDIR}/daffy-dotfiles || exit
${HOMEDIR}/daffy-dotfiles/install.sh

cd ${DEV_DIR}/openstack/ || exit

