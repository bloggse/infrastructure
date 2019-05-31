#!/bin/bash
## Load variables to use in this script
INIT_PHASE="4_post_integration_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Restart vpn_ctrl and add routing"

# Restart tinc_vpn_ctrl so all connections can be established
systemctl restart tinc_vpn_ctrl &>$_mute_

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

echoStep "Start confd now that vpn_ctrl should be up"
systemctl enable confd &>$_mute_
systemctl --no-block start confd &>$_mute_

##
## Finish up with some status checks
##
# systemctl status confd
s="`ping etcd001 -c 1 -q | grep "0% packet loss"`"
printf "${_bld}$NODE_NAME${bld_} $s\n"
