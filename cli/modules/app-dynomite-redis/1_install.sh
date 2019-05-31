#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

_dynomite_ver=0.7.0

echoStep "Install Redis"
pkg install -y redis-server &>$_mute_
systemctl enable redis-server.service &>$_mute_

echoStep "Install Dynomite"
if ! hash dynomite &>$_mute_; then
  pkg install -y autoconf automake git libtool libssl-dev &>$_mute_

  curl -L https://github.com/Netflix/dynomite/archive/v$_dynomite_ver.tar.gz -o dynomite-$_dynomite_ver.tar.gz &>$_mute_
  tar xvf dynomite-$_dynomite_ver.tar.gz &>$_mute_
  cd dynomite-$_dynomite_ver &>$_mute_
  autoreconf -fvi &>$_mute_
  ./configure --enable-debug=yes &>$_mute_
  make &>$_mute_; make install &>$_mute_
  cd /root
else
  echo "Dynomite already installed"
fi