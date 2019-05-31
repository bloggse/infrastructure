#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Configure flannel network"
# Open up ports in firewall https://github.com/coreos/flannel/blob/master/Documentation/troubleshooting.md
firewall-cmd --permanent --zone="limited" --add-port="8285/udp" &>$_mute_
firewall-cmd --permanent --zone="limited" --add-port="8472/udp" &>$_mute_
firewall-cmd --permanent --zone="limited" --add-port="51820/udp" &>$_mute_
#firewall-cmd --permanent --zone="vpn" --add-interface="flannel.1"
firewall-cmd --permanent --zone="vpn" --add-interface="flannel-wg" &>$_mute_
systemctl restart firewalld &>$_mute_


# Only update and restart if flanneld has changed. This minimizes issues
# with flannel network failing on reconfig
_first() {
  outp=$1
}
if [ -f /etc/systemd/system/flanneld.service ];
then
  _first `sha1sum /etc/systemd/system/flanneld.service`; _tmp1=$outp
fi
_first `sha1sum $INIT_PHASE/flanneld.service`; _tmp2=$outp

if [[ "$_tmp1" != "$_tmp2" ]];
then
  sudo cp -f $INIT_PHASE/flanneld.service /etc/systemd/system/
  systemctl daemon-reload &>$_mute_
  systemctl restart flanneld &>$_mute_
else
  echo "flanneld.service has not changed"
fi

echoStep "Install script to update /etc/hosts"
mkdir -p /usr/local/bin
cp -f $INIT_PHASE/update_hosts.sh /usr/local/bin/
chmod 755 /usr/local/bin/update_hosts.sh

echoStep "Configure routing through etcd"
cp -rf $INIT_PHASE/conf.d/* /etc/confd/conf.d/
cp -rf $INIT_PHASE/templates/* /etc/confd/templates/
systemctl restart confd &>$_mute_
