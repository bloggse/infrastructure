#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install minio from binaries"
if [ ! -f /usr/local/sbin/minio ];
then
  curl -L https://dl.min.io/server/minio/release/linux-amd64/minio -o minio &>$_mute_
  chmod +x minio
  mv ./minio /usr/local/sbin/minio
fi