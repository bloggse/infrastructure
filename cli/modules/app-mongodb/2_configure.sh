#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

APP_TYPE="service"
APP_NAME="mongodb"
_service_name="mongod"
_systemd_unit_file="/lib/systemd/system/$_service_name.service"
# /etc/systemd/system/mongos.service 

echoStep "Register service"

/bin/bash /usr/local/bin/register_app.sh register-app --type=$APP_TYPE --name=$APP_NAME --value='{ "publish": { "ip": "127.0.0.1", "port": 27017 }, "env_prefix": "MONGODB", "env": { "PROTOCOL": "mongodb:", "HOST": "127.0.0.1", "PORT": 27017, "PATH": "", "REPLICA_SET": "rs0", "USER": "testuser", "PASSWORD": "testuser" }}'

echoStep "Update mongodb systemd unit config"

EXEC_START_POST="ExecStartPost=/usr/local/bin/register_app.sh register-app-instance"
EXEC_STOP_PRE="ExecStop=/usr/local/bin/register_app.sh unregister-app-instance"

instance_params=$(cat <<EOF
--type=$APP_TYPE --name=$APP_NAME --value="{ \\\"node\\\": \\\"$NODE_NAME\\\", \\\"ip\\\": \\\"$NODE_NAME\\\", \\\"port\\\": 27017 }"
EOF
)

# TODO: Delete line with PID file "PIDFile=/var/run/mongodb/mongod.pid"
sed -i "/^PIDFile=\/var\/run\/mongodb\/mongod.pid/d" $_systemd_unit_file

if ! grep "^$EXEC_START_POST" $_systemd_unit_file; then
  # Add line below ExecStart
  sed -i "/^ExecStart=/ s|$|\n$EXEC_START_POST $instance_params\n|" $_systemd_unit_file
  _restart="true"
fi

if ! grep "^$EXEC_STOP_PRE" $_systemd_unit_file; then
  # Add line below ExecStartPost
  sed -i "/^ExecStartPost=/ s|$|\n$EXEC_STOP_PRE $instance_params|" $_systemd_unit_file 
  _restart="true"
fi


if [ ! -z "$_restart" ]; then
  echoStep "Reload systemd and restart mongodb"
  systemctl daemon-reload
  systemctl restart $_service_name
else
  echoStep "We didn't make any changes to systemd config so we don't need to restart mongodb"
fi