#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install confd templates"
mkdir -p /etc/cluster

cp -rf $INIT_PHASE/conf.d/* /etc/confd/conf.d/
cp -rf $INIT_PHASE/templates/* /etc/confd/templates/
systemctl restart confd &>$_mute_
# HA Proxy is restarted by confd rule

echoStep "Install app registration script"
mkdir -p /usr/local/bin
cp -f $INIT_PHASE/register_app.sh /usr/local/bin/
chmod 755 /usr/local/bin/register_app.sh