#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install git"
pkg install -y git &>$_mute_

echoStep "Install build essentials equivalent"
pkg install -y gcc-c++ gcc glibc-devel make &>$_mute_

echoStep "Install Node.js 12"
if isLinux centos; then
  # node-sass binding not yet available for Node 12
  curl -sL https://rpm.nodesource.com/setup_10.x | bash - &>$_mute_
  pkg update &>$_mute_
  pkg install -y nodejs &>$_mute_
  echo "If Node.js isn't installed, check instructions at https://github.com/nodesource/distributions/blob/master/README.md"
elif isLinux debian; then
  # node-sass binding not yet available for Node 12
  curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash - &>$_mute_
  pkg update &>$_mute_
  pkg install -y nodejs &>$_mute_
fi