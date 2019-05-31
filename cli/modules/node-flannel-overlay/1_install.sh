#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install wireguard"
# Install wireguard for security
# (epel-release is available from setup-node-base so perhaps remove install here?)
if isLinux centos;
then
  if [ ! -f /etc/yum.repos.d/wireguard.repo ];
  then
    pkg install -y linux-headers-$(uname -r) &>$_mute_
    pkg install -y epel-release &>$_mute_
    curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo &>$_mute_
    pkg update &>$_mute_
    pkg install -y wireguard-dkms wireguard-tools &>$_mute_
  fi
elif isLinux debian;
then
  # If we don't install the linux-headers headers package, wireguard won't install properly
  # If the command `$ modprobe wireguard` has no output, all is good. Otherwise you get:
  # > modprobe: FATAL: Module wireguard not found in directory /lib/modules/4.9.0-8-amd64
  pkg install -y linux-headers-$(uname -r) &>$_mute_
  echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
  printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
  pkg update &>$_mute_ # Need to update after 
  pkg install -y wireguard &>$_mute_
fi

if ! modprobe wireguard &>$_mute_; then
  echoErr "WARNING! wireguard wasn't installed properly. Make sure you have installed 'linux-headers-$(uname -r)'"
fi

echoStep "Install flannel"
# Install flannel
if [ ! -f /usr/local/sbin/flanneld ]; then
  sudo gunzip -c $INIT_PHASE/bin/flanneld_0.11.0_amd64.gz > /usr/local/sbin/flanneld
  sudo chmod 755 /usr/local/sbin/flanneld
fi
# To update flannel, download latest release from https://github.com/coreos/flannel/releases
# 