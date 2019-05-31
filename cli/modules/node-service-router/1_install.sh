#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "****** Install HA Proxy ******"
pkg -y install haproxy &>$_mute_
