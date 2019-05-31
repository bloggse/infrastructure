#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

MINIO_USER=$MINIO_USER || "minio"

echoStep "Create Minio user ($MINIO_USER)"
adduser --system --no-create-home --group $MINIO_USER &>$_mute_

echoStep "Register service"
# The minio service
/bin/bash /usr/local/bin/register_app.sh register-app --type=$APP_TYPE --name=$APP_NAME --value='{ "publish": { "ip": "127.0.0.1", "port": 9000 }, "env_prefix": "MINIO", "env": { "PROTOCOL": "http:", "HOST": "127.0.0.1", "PORT": 9000, "PATH": "" }}'

# The minio browser frontend
/bin/bash /usr/local/bin/register_app.sh register-app --type=frontend --name=minio-browser --value='{ "publish": { "ip": "127.0.0.1", "port": 9001 }, "env_prefix": "MINIO_BROWSER", "env": { "PROTOCOL": "http:", "HOST": "127.0.0.1", "PORT": 9001, "PATH": "" }}'

echoStep "Create data directory /data/minio"
mkdir -p /data/minio
chown $MINIO_USER:$MINIO_USER -R /data/minio

echoStep "Create /etc/minio"
mkdir -p /etc/minio/
chown $MINIO_USER:$MINIO_USER -R /etc/minio

echoStep "Register instance with etcd to allow forming a cluster"
/usr/local/bin/register_app.sh register-app-instance --type=$APP_TYPE --name=$APP_NAME --value="{ \"node\": \"$NODE_NAME\", \"ip\": \"$NODE_NAME\", \"port\": 19000 }"
# On tear down: ExecStop=/usr/local/bin/register_app.sh unregister-app-instance --type=[% app.type %] --name=[% app.name %]

echoStep "Install /etc/default/minio confd template"
# cat <<EOT > /etc/default/minio
# # Volume to be used for MinIO server.
# MINIO_VOLUMES="/data/minio"
# # Use if you want to run MinIO on a custom port.
# MINIO_OPTS="--address :19000"
# # Activate browser
# MINIO_BROWSER=on

# # TODO: Move these secrets to a secret place...
# # Access Key of the server.
# MINIO_ACCESS_KEY=[access_key]
# # Secret key of the server.
# MINIO_SECRET_KEY=[password]
# EOT
# chmod 644 /etc/default/minio
cp $INIT_PHASE/minio.tmpl /etc/confd/templates/minio.tmpl
cp $INIT_PHASE/minio.toml /etc/confd/conf.d/minio.toml
systemctl restart confd

echoStep "Install minio systemd unit config"
cp -f $INIT_PHASE/minio.service /etc/systemd/system/$APP_NAME.service
chmod 644 /etc/systemd/system/$APP_NAME.service

systemctl daemon-reload &>$_mute_
systemctl enable $APP_NAME
systemctl restart $APP_NAME
