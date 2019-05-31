#!/bin/bash
##
## Register this node with etcd server
##
SERVICES='[% FOREACH s IN node.services %]"[% s %]"[%- ", " IF not loop.last %][% END %]'

registerNode() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/node/[% node.name %] \
    -XPUT -d value="{\"name\":\"[% node.name %]\", \"vpn_ip\":\"$1\", \"physical_ip\":\"[% node.physical_ip %]\", \"services\": [ $SERVICES ]}" &>/dev/null
}

unregisterNode() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/node/[% node.name %]  -XDELETE &>/dev/null
}

if [ "$1" = "register" ]; then
  read _n1 subnet _n2 <<< $(ip -4 a l | grep "flannel-wg$");
  vpn_ip=`echo $subnet | cut -d '/' -f1`
  
  echo "Registering with VPN IP: $vpn_ip"
  registerNode $vpn_ip
  exit 0
fi

if [ "$1" = "unregister" ]; then
  unregisterNode
  exit 0
fi