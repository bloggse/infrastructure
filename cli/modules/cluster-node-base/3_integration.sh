#!/bin/bash
## Load variables to use in this script
INIT_PHASE="3_integration"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Fetch output"
rsync -avz --no-owner --no-group -L -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" root@$NODE_NAME.$DOMAIN:/root/output/* output/ &>$_mute_

echoStep "Gather Tinc host keys for vpn_ctrl"

mkdir -p vpn_ctrl_keys
IFS=' '
for member in $ETCD_NODES; do
  ln -sfn `(cd ../.. && pwd)`/${member}/cluster-ctrl-base/output/vpn_ctrl_keys/${member} vpn_ctrl_keys/

  rsync -rz -L -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" output/vpn_ctrl_keys/${NODE_NAME} root@${member}.$DOMAIN:/etc/tinc/vpn_ctrl/hosts/ &>$_mute_

  row="\"$NODE_VPN_IP $NODE_NAME\""
  sed_params="\"s/^[0-9\.]* $NODE_NAME/$NODE_VPN_IP $NODE_NAME/g\""

  read -r -d '' remote_script <<-EOF
    sed -i $sed_params /etc/hosts
    if ! grep $row /etc/hosts; then
      # Or append an entry to end of file
      echo $row >> /etc/hosts
    fi
    systemctl restart tinc_vpn_ctrl
EOF

  #echo "ssh -i $HOME/.ssh/$SSH_KEY_NAME root@$member.$DOMAIN $SSH_OPTS /bin/bash"
  ssh -i $HOME/.ssh/$SSH_KEY_NAME root@$member.$DOMAIN $SSH_OPTS /bin/bash "$remote_script" &>$_mute_
done

# Sync host keys to remote
echoStep "Send Tinc etcd host keys to node"
# echo "root@$NODE_NAME.$DOMAIN"
rsync -rz -L -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" vpn_ctrl_keys/* root@$NODE_NAME.$DOMAIN:/etc/tinc/vpn_ctrl/hosts/ &>$_mute_

