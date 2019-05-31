#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install application repos"
if [ -d $INIT_PHASE/bin/app.git ]; then
  rm -rf $INIT_PHASE/bin/app.git &>$_mute_
fi
tar xvf $INIT_PHASE/bin/app.git.tgz &>$_mute_

mkdir -p /var/www/
if [ -d /var/www/$APP_NAME ]; then
  (cd /var/www/$APP_NAME && git reset --hard &>$_mute_)
  (cd /var/www/$APP_NAME && git pull --force) # &>$_mute_)
else
  git clone app.git /var/www/$APP_NAME &>$_mute_
fi

(cd /var/www/$APP_NAME && npm i &>$_mute_)
(cd /var/www/$APP_NAME && npm run build &>$_mute_)

echoStep "Install systemd unit"
cp -f $INIT_PHASE/app.service /etc/systemd/system/$APP_NAME.service
chmod 644 /etc/systemd/system/$APP_NAME.service

echoStep "(Re-)starting app..."
systemctl daemon-reload &>$_mute_
systemctl enable $APP_NAME &>$_mute_
systemctl restart $APP_NAME &>$_mute_

echoStep "Register app"
/bin/bash /usr/local/bin/register_app.sh register-app --type=$APP_TYPE --name=$APP_NAME --value="{ \"publish\": { \"ip\": \"127.0.0.1\", \"port\": $EXPOSE }, \"env_prefix\": \"$ENV_PREFIX\", \"env\": { \"PROTOCOL\": \"http:\", \"HOST\": \"127.0.0.1\", \"PORT\": $EXPOSE, \"PATH\": \"\" }}"

echoStep "STATUS CHECK"
systemctl status $APP_NAME