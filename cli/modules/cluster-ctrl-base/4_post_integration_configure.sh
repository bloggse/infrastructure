#!/bin/bash
## Load variables to use in this script
INIT_PHASE="4_post_integration_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Restart vpn_ctrl and add routing"

# Restart tinc_vpn_ctrl so all connections can be established
systemctl restart tinc_vpn_ctrl &>$_mute_

# Set up routing for etcd hosts
IFS=$'\n'
for row in $ETCD_NODE_HOSTS_FILE; do
  IFS=' ' read IP NAME <<< $row
  if [[ $NAME != $NODE_NAME ]]; then
    # Update IP if we find it
    # Try sed command here: https://tio.run/#sed-gnu 
    sed -i "s/^[0-9\.]* $NAME/$row/g" /etc/hosts
    if ! grep "$row" /etc/hosts; then
      # Or append an entry to end of file
      echo $row >> /etc/hosts
    fi
  fi
done

echoStep "Configure etcd"
mkdir -p /etc/etcd/
sudo cp -f $INIT_PHASE/etcd.conf /etc/etcd/etcd.conf

if isLinux debian; then
  cp $INIT_PHASE/etcd.service_debian /etc/systemd/system/etcd.service

  systemctl daemon-reload &>$_mute_
  systemctl start etcd &>$_mute_
else
  systemctl restart etcd
fi

echoStep "Initialize data in etcd"
if ! etcdctl ls /node 2>$_mute_; then
  etcdctl mkdir /ingress 2>$_mute_
  etcdctl mkdir /frontend 2>$_mute_
  etcdctl mkdir /backend 2>$_mute_
  etcdctl mkdir /service 2>$_mute_
  etcdctl mkdir /node 2>$_mute_
fi

echoStep "Install confd"

# Create config directories
mkdir -p /etc/confd/conf.d
mkdir -p /etc/confd/templates

# Create service https://medium.com/@benmorel/creating-a-linux-service-with-systemd-611b5c8b91d6
sudo cp -f $INIT_PHASE/confd.service /etc/systemd/system/confd.service
systemctl daemon-reload &>$_mute_
systemctl enable confd &>$_mute_
systemctl --no-block start confd &>$_mute_

##
## Finish up with some status checks
##
# systemctl status etcd 
# systemctl status confd
etcdctl cluster-health
