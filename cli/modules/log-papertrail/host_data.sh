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

node = {
  name => '$node',
  physical_ip => '${NODE_PHYSICAL_IP}'
}

papertrail_log_target = '$PAPERTRAIL_LOG_TARGET'
-%]
EOF
}
