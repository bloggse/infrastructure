#!/bin/bash
rm -f /tmp/new_hosts
cat /etc/hosts | sed '/# flannel-wg$/d' > /tmp/new_hosts
cat "$1" >> /tmp/new_hosts
mv /etc/hosts /etc/hosts.old
mv /tmp/new_hosts /etc/hosts