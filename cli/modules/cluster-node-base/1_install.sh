#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

## Create output directory
mkdir -p $HOME/output
sudo rm -rf $HOME/output/*

echoStep "Install Firewalld"
pkg install -y firewalld &>$_mute_
if [ ! -d "/etc/firewalld" ]
then
  echoErr "Installation of Firewalld failed, missing /etc/firewalld"
fi

sudo cp -f $INIT_PHASE/limited.xml /etc/firewalld/zones/limited.xml
sudo cp -f $INIT_PHASE/vpn.xml /etc/firewalld/zones/vpn.xml
systemctl restart firewalld &>$_mute_

printf "Starting firewalld"; retryUntilSuccess "firewall-cmd --get-default-zone"
firewall-cmd --set-default-zone=limited &>$_mute_

echoStep "Install Tinc"

if isLinux centos; then
  pkg install -y epel-release &>$_mute_
fi
pkg install -y net-tools nmap tinc &>$_mute_


echoStep "[DISABLED] Install some usefule build tools"
# pkg install -y git gcc gcc-c++ glibc-devel make &>$_mute_

echoStep "Install app utils"
pkg install -y jq &>$_mute_

echoStep "Install confd binary"
mkdir -p /opt/confd/bin
sudo cp -f $INIT_PHASE/bin/confd-0.16.0-linux-amd64 /opt/confd/bin/confd
chmod 755 /opt/confd/bin/confd