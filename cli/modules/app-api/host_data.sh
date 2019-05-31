#!/bin/bash
generateHostData() {
  cat <<EOF
[%
module_name = '$module'
init_phase = '$init_phase'

# === Application settings ===
app = {
  name => '$APP_NAME'
  type => '$APP_TYPE'
  work_dir => '$WORK_DIR'
  exec_path => '$EXEC_PATH'
  expose => $EXPOSE,
  env_prefix => '$ENV_PREFIX'
}
# === ==================== ===

deploy = {
  ssh_key_name => '$SSH_KEY_NAME',
  domain => '$DOMAIN'
}

cluster_uuid = $CLUSTER_UUID

node = {
  name => '$node',
  physical_ip => '${NODE_PHYSICAL_IP}'
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
