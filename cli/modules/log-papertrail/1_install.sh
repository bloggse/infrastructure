#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install helper libs"
pkg install -y rsyslog-gnutls &>$_mute_

echoStep "Setup TLS for Paperetrail" &>$_mute_
curl -o /etc/papertrail-bundle.pem https://papertrailapp.com/tools/papertrail-bundle.pem &>$_mute_
upsertLine /etc/rsyslog.conf '# Settings for Papertrailapp.com' &>$_mute_
upsertLine /etc/rsyslog.conf '$DefaultNetstreamDriverCAFile /etc/papertrail-bundle.pem # trust these CAs' &>$_mute_
upsertLine /etc/rsyslog.conf '$ActionSendStreamDriver gtls # use gtls netstream driver' &>$_mute_
upsertLine /etc/rsyslog.conf '$ActionSendStreamDriverMode 1 # require TLS' &>$_mute_
upsertLine /etc/rsyslog.conf '$ActionSendStreamDriverAuthMode x509/name # authenticate by hostname' &>$_mute_
upsertLine /etc/rsyslog.conf '$ActionSendStreamDriverPermittedPeer *.papertrailapp.com' &>$_mute_

echoStep "Send logs to Papertrail"
upsertLine /etc/rsyslog.conf "*.*    @@$PAPERTRAIL_LOG_TARGET"  &>$_mute_
systemctl restart rsyslog &>$_mute_