#!/bin/bash
## Load variables to use in this script
INIT_PHASE="2_configure"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Initialize flannel overlay network settings in etcd"
echo "Interface name is 'flannel-wg' and subnet 10.5.0.0/16"
etcdctl set /coreos.com/network/config &>$_mute_ <<'EOF'
{
  "Network": "10.5.0.0/16",
  "Backend": {
    "Type": "extension",
    "PreStartupCommand": "wg genkey | tee privatekey | wg pubkey",
    "PostStartupCommand": "export SUBNET_IP=`echo $SUBNET | cut -d'/' -f 1`; `which ip` link del flannel-wg 2>$_mute_; `which ip` link add flannel-wg type wireguard && wg set flannel-wg listen-port 51820 private-key privatekey && `which ip` addr add $SUBNET_IP/32 dev flannel-wg && `which ip` link set flannel-wg up && `which ip` route add $NETWORK dev flannel-wg",
    "ShutdownCommand": "ip link del flannel-wg",
    "SubnetAddCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY endpoint $PUBLIC_IP:51820 allowed-ips $SUBNET",
    "SubnetRemoveCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY remove"
  }
}
EOF

# "PostStartupCommand": "iptables -A FORWARD -i flannel-wg -j ACCEPT;"
# "PostShutdownCommand": "iptables -D FORWARD -i flannel-wg -j ACCEPT;",
# wg set flannel-wg listen-port 51820 private-key privatekey persistent-keepalive 25