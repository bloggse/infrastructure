#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Register node with etcd"
waitForServer etcd001
/bin/bash $INIT_PHASE/register_node.sh register
