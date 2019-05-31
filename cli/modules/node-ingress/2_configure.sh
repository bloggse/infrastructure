#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Configure OpenRESTY"

cp -f $INIT_PHASE/openresty.service /lib/systemd/system/openresty.service
LUA_PATH="`luarocks path --lr-path`" &>$_mute_
sed -i "s|__LUA_PATH__|$LUA_PATH|g" /lib/systemd/system/openresty.service &>$_mute_

mkdir -p /etc/resty-auto-ssl
chown $NGINX_USER:$NGINX_USER /etc/resty-auto-ssl
chmod 775 /etc/resty-auto-ssl

systemctl daemon-reload &>$_mute_
systemctl restart openresty &>$_mute_

systemctl start firewalld &>$_mute_
printf "Starting firewalld"; retryUntilSuccess "firewall-cmd --get-default-zone"
firewall-cmd --permanent --zone="limited" --add-service=http --add-service=https #&>$_mute_
systemctl restart firewalld &>$_mute_

printf "Generate validation keys... "
if [ ! -f /etc/ssl/resty-auto-ssl-fallback.crt ]; then
  openssl req -new \
    -newkey rsa:2048 \
    -days 3650 \
    -nodes -x509 \
    -subj '/CN=sni-support-required-for-valid-ssl' \
    -keyout /etc/ssl/resty-auto-ssl-fallback.key \
    -out /etc/ssl/resty-auto-ssl-fallback.crt &>$_mute_
fi

printf "install confd templates... "
cp -rf $INIT_PHASE/conf.d/* /etc/confd/conf.d/
cp -rf $INIT_PHASE/templates/* /etc/confd/templates/
systemctl restart confd &>$_mute_
echo "done!"

echoStep "Register node with etcd"
waitForServer etcd001
/bin/bash $INIT_PHASE/register_node.sh register
