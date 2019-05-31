#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install node registration script"
mkdir -p /usr/local/bin
cp -f $INIT_PHASE/register_node.sh /usr/local/bin/
chmod 755 /usr/local/bin/register_node.sh

echoStep "Install app registration script"
mkdir -p /usr/local/bin
cp -f $INIT_PHASE/register_app.sh /usr/local/bin/
chmod 755 /usr/local/bin/register_app.sh

echoStep "Register node with etcd"
waitForServer etcd001
/bin/bash /usr/local/bin/register_node.sh register
# TODO: We should check that the node successfully registered

