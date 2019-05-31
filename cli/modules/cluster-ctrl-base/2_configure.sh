#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Deactivate password login over SSH"
upsertLine /etc/ssh/sshd_config "ChallengeResponseAuthentication no"
upsertLine /etc/ssh/sshd_config "PasswordAuthentication no"
upsertLine /etc/ssh/sshd_config "UsePAM no"
systemctl reload ssh

echoStep "Configure vpn_ctrl"
mkdir -p /var/log/tinc # Use this for graphviz export

sudo cp -f $INIT_PHASE/tinc/tinc.service /etc/systemd/system/tinc_$VPN_CTRL.service

# Open up ports in firewall (not needed, because using default)
systemctl restart firewalld &>$_mute_
firewall-cmd --permanent --zone="limited" --add-port="$TINC_VPN_PORT/tcp" --add-port="$TINC_VPN_PORT/udp" &>$_mute_
firewall-cmd --permanent --zone="vpn" --add-interface="vpn_ctrl" &>$_mute_
systemctl restart firewalld &>$_mute_

# Create nets.boot if it doesn't exist
if [ ! -f '/etc/tinc/nets.boot' ]; then
  mkdir -p /etc/tinc
  sudo cp -f $INIT_PHASE/tinc/nets.boot /etc/tinc/nets.boot
fi

mkdir -p /etc/tinc/vpn_ctrl/hosts
sudo cp -f $INIT_PHASE/tinc/tinc.conf /etc/tinc/$VPN_CTRL/tinc.conf
sudo cp -f $INIT_PHASE/tinc/tinc-up /etc/tinc/$VPN_CTRL/tinc-up
chmod 755 /etc/tinc/$VPN_CTRL/tinc-up
sudo cp -f $INIT_PHASE/tinc/tinc-down /etc/tinc/$VPN_CTRL/tinc-down
chmod 755 /etc/tinc/$VPN_CTRL/tinc-down

# Create hostkey file if it doesn't exist
if [ ! -f '/etc/tinc/vpn_ctrl/hosts/$NODE_NAME' ]; then
  sudo cp -f $INIT_PHASE/tinc/hostkey /etc/tinc/$VPN_CTRL/hosts/$NODE_NAME
fi

# if /etc/tinc/netname/hosts/inventory_hostname doesn't contain "-----END RSA PUBLIC KEY-----"
# we need to create a new private key
if [ -z `grep -q "/^-----END RSA PUBLIC KEY-----$/" "/etc/tinc/$VPN_CTRL/hosts/$NODE_NAME"` ]; then
  [ -f "/etc/tinc/$VPN_CTRL/rsa_key.priv" ] && sudo rm -f "/etc/tinc/$VPN_CTRL/rsa_key.priv"
  
  # create tinc private key (and append public key to tincd hosts file)
  tincd -n $VPN_CTRL -K4096 &>$_mute_
  systemctl daemon-reload &>$_mute_
  systemctl restart tinc_$VPN_CTRL &>$_mute_
fi

# Copying the generated tinc key to a output so we can fetch it from the deploy server and
# distribute
mkdir -p $HOME/output/vpn_ctrl_keys
sudo cp -f /etc/tinc/$VPN_CTRL/hosts/$NODE_NAME $HOME/output/vpn_ctrl_keys

##
## Now we need to release control back to deployment server so
## we can retriev host keys and connect vpn_ctrl
##
