#!/bin/bash
## Load variables to use in this script
INIT_PHASE="99_teardown"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Stopping app..."
systemctl stop $APP_NAME &>$_mute_

echoStep "Remove application repos"
if [ -d /var/www/$APP_NAME ]; then
  rm -rf /var/www/$APP_NAME
fi

echoStep "Remove systemd unit"
rm -f $INIT_PHASE/app.service /etc/systemd/system/$APP_NAME.service

# If no instances left, remove app
echoStep "All instances gone, unregister app instance"
/bin/bash /usr/local/bin/register_app.sh unregister-app --type=$APP_TYPE --name=$APP_NAME &>$_mute_
