#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

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

echoStep "Install confd binary"
mkdir -p /opt/confd/bin
sudo cp -f $INIT_PHASE/bin/confd-0.16.0-linux-amd64 /opt/confd/bin/confd
chmod 755 /opt/confd/bin/confd

echoStep "Install etcd"
if isLinux centos; then
  pkg install -y etcd &>$_mute_
elif isLinux debian; then
  ETCD_VER=v3.3.12
  echo "Manual install of etcd v$ETCD_VER"

  # choose either URL
  GOOGLE_URL=https://storage.googleapis.com/etcd
  # GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
  DOWNLOAD_URL=${GOOGLE_URL}

  rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
  rm -rf $HOME/etcd-download-test && mkdir -p $HOME/etcd-download-test

  curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz &>$_mute_
  tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C $HOME/etcd-download-test --strip-components=1 &>$_mute_
  # rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

  if ! $HOME/etcd-download-test/etcd --version &>$_mute_; then
    echoErr "WARNING! The downloaded build of etcd failed test."
  fi
  if ! ETCDCTL_API=3 $HOME/etcd-download-test/etcdctl version &>$_mute_; then
    echoErr "WARNING! The downloaded build of etcdctl (control file) failed test."
  fi
  
  # Install
  if [ ! -f /usr/local/bin/etcd ]
  then
    (cd $HOME/etcd-download-test/; cp etcd etcdctl /usr/local/bin)
  fi

  # User and group
  groupadd --system etcd &>$_mute_
  useradd -s /sbin/nologin --system -g etcd etcd &>$_mute_
  
  # Data dir
  mkdir -p /var/lib/etcd/
  chown -R etcd:etcd /var/lib/etcd/
fi

