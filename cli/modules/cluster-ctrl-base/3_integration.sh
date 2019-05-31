#!/bin/bash
## Load variables to use in this script
INIT_PHASE="3_integration"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Fetch my tinc keys"
rsync -avz --no-owner --no-group -L -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" root@$NODE_NAME.$DOMAIN:/root/output/* output/ &>$_mute_

echoStep "Share Tinc host keys for vpn_ctrl among etcd nodes"

IFS=' '
for member in $ETCD_NODES; do
  # Share keys among etcd nodes
  if [[ $member != $NODE_NAME ]]; then
    rsync -rz -L -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" output/vpn_ctrl_keys/* root@${member}.$DOMAIN:/etc/tinc/vpn_ctrl/hosts/ &>$_mute_
  fi
done
