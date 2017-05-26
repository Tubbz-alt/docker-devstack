#!/bin/bash
cd /home/stack/devstack
./unstack.sh
sudo rm -rf /opt/stack/logs/*
sudo journalctl --vacuum-size=100M
sudo dbus-uuidgen > /etc/machine-id

