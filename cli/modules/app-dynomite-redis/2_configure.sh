#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Create Redis user"
REDIS_USER=$REDIS_USER || "redis"
adduser --system --no-create-home --group $REDIS_USER &>$_mute_

echoStep "Configure redis.conf and redis.service"
# https://tecadmin.net/install-redis-on-debian-9-stretch/
mkdir -p /etc/redis
cp -f $INIT_PHASE/redis.conf /etc/redis/redis.conf
chown $REDIS_USER:$REDIS_USER /etc/redis
chmod 644 /etc/redis/redis.conf

cp -f $INIT_PHASE/redis.service /etc/systemd/system/redis.service
chmod 644 /etc/systemd/system/redis.service

systemctl daemon-reload
systemctl enable redis.service

echoStep "Configure dynomite.yml and dynomite.service"
# http://www.dynomitedb.com
mkdir -p /etc/dynomite
mkdir -p /run/var/dynomite

cp -f $INIT_PHASE/dynomite.yml.toml /etc/confd/conf.d/
cp -f $INIT_PHASE/dynomite.yml.tmpl /etc/confd/templates/
systemctl restart confd &>$_mute_

cp -f $INIT_PHASE/dynomite.service /etc/systemd/system/dynomite.service
chmod 644 /etc/systemd/system/dynomite.service

systemctl daemon-reload
systemctl enable dynomite &>$_mute_
systemctl restart dynomite &>$_mute_

echoStep "Register service with etcd"

/bin/bash /usr/local/bin/register_app.sh register-app --type=$APP_TYPE --name=$APP_NAME --value='{ "publish": { "ip": "127.0.0.1", "port": 6380 }, "env_prefix": "REDIS", "env": { "PROTOCOL": "redis:", "HOST": "127.0.0.1", "PORT": 6380, "PATH": "" }}'

# These are the dyno helpers that expose redis as a cluster. They need to be registered early so we
# get proper configuration
/bin/bash /usr/local/bin/register_app.sh register-app-instance --type=service --name=dynomite --value="{ \"node\": \"$NODE_NAME\", \"ip\": \"$NODE_NAME\", \"port\": $DYNO_PORT }"
# On stop:
#/bin/bash /usr/local/bin/register_app.sh unregister-app-instance --type=service --name=dynomite

