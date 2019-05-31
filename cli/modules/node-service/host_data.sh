#!/bin/bash
generateHostData() {
  _node_nr=$((10#${node//[^0-9]/}))

  cat <<EOF
[%
module_name = '$module'
init_phase = '$init_phase'

deploy = {
  ssh_key_name => '$SSH_KEY_NAME',
  domain => '$DOMAIN'
}

cluster_uuid = $CLUSTER_UUID

node = {
  name => '$node',
  physical_ip => '${NODE_PHYSICAL_IP}',
  services => []
}

vpn_ctrl = {
  vpn_interface => 'vpn_ctrl',
  vpn_ip => '${CTRL_BASE_VPN_IP}.$_node_nr',
  vpn_netmask => '255.255.255.0',
  vpn_subnet_sidr_netmask => '32',
  vpn_port => '760'
}

etcd = {
  vpn_ip => '${CTRL_PREFIX}001',
  port => '2379',
  nodes => [
    { name => '${CTRL_PREFIX}001', vpn_ip => '${CTRL_BASE_VPN_IP}.1' },
    { name => '${CTRL_PREFIX}002', vpn_ip => '${CTRL_BASE_VPN_IP}.2' },
    { name => '${CTRL_PREFIX}003', vpn_ip => '${CTRL_BASE_VPN_IP}.3' }
  ]
}
-%]
EOF
}
