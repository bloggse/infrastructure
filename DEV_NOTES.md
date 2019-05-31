These are notes written during development.

# Refactor infrastructure like this:

- Use custom cli to create and scale the cluster
  We need to be able to scale elastically and setting up the Tinc meshes

- Use Ansible to install Redis, Mongodb, Elastic, Nginx
  There are lots of scripts out there and it will actually save time
  This is also something we don't do all the time so performance is less important

- Use custom cli to deploy and scale apps
  We need to be able to scale elastically and probably perform this from the controller plane

## 0. Create controller
- etcd cluster
- vpn_ctrl Tinc mesh

## 1. Create node
- worker
- ingress
- service

## 2. Connect to Controller VPN
1. Get config for controller001-003
  - Tinc keys
  - Tinc node names
  - VPN IP
  - Real IP
  - Tinc port
2. For each machine to connect
2.1 Create Tinc vpn_ctrl
2.2 Add host keys
2.3 Update tinc.conf
2.4 Update nets.boot
2.6 Updated firewalld
2.7 Update /etc/hosts
2.8 Get Tinc key and place on controller001-003
(QUESTION: Do we really need to update /etc/hosts for controller?)
2.9 Configure and fire up Tinc service

## 3. Setup overlay network with flannel over wireguard

## 4. Register node with control plane
- 

## Remove a worker node from cluster
1. Drain alla applications
2. De-register from Controller
3. Remove DNS-registration
4. Destroy machine

## Deploy ingress to ingress node
- use Ansible to target machines
- Configure floating IP? (should controller do this?)
- Register ingress nodes?
We can have several different ingress nodes

## Deploy a service to a service node
- use Ansible to target machines
- register service with controller

## Deploy an application to a worker node
1. Deploy by git clone (specific commit)
2. Run build script
3. Register app and app node with controllers

  - is backend
  - needs ingress

## Update an application
1. For each instance of that application
1.1 Deploy new instance of application
1.2 Verify that it is accesible
1.3 Register as new instance and remove the old instance from

  /apps/[app_name]/backend and /apps/[app_name]/ingress

1.4 When no more incomming, remove old instance from node and cleanup

## Remove an instance of an application
1. Remove the instance from
  
  /apps/[app_name]/backend and /apps/[app_name]/ingress

2. When no more incomming, remove instance from node and cleanup

## Remove application
1 For each instance of the application
1.1 Remove the instance from

  /apps/[app_name]/backend and /apps/[app_name]/ingress

1.2 When no more incomming, remove instance from node and cleanup
2. Remove the application from

  /apps/[app_name]


## Configure Cluster Ingress
- Generate haproxy routing from /apps/[app_name]/ingress/instances
- Generate Nginx incoming config from /apps/[app_name]/ingress/publish

Check if we have a padlock:
https://www.whynopadlock.com

Currently we need to generate the padlock with the ingress for apps deactivated.

Check let's encrypt calls:
https://crt.sh/?Identity=%25ingress016.flstr.cloud&iCAID=16418

## Create Tinc mesh to access control plane (etcd-cluster)
1 For each machine to connect
1.1 Create Tinc vpn_ctrl
1.2 Share host keys with etcd-cluster
1.3 Update tinc.conf
1.4 Update nets.boot
1.6 Updated firewalld
1.7 Update /etc/hosts
1.8 Configure and fire up Tinc service


# Installing Template Toolkit on Mac OS X
http://www.tt2.org/download/index.html

```
yum -y install perl perl-devel gcc
curl -L http://cpan.org/modules/by-module/Template/Template-Toolkit-2.26.tar.gz | tar zxf -
cd Template-Toolkit-2.26/
perl Makefile.PL
make
# make test
sudo make install
```

## Install on Centos 7 using 
```
yum -y install perl perl-devel gcc cpan
sudo cpan -y Template
```

# Render templates
http://template-toolkit.org/docs/tools/index.html

# Templating manual
http://template-toolkit.org/docs/manual/index.html

# Introduction to templating
https://www.oreilly.com/library/view/perl-template-toolkit/0596004761/ch01.html

http://tldp.org/LDP/abs/html/string-manipulation.html

Parse integer from string:

  inpStr=node001
  newStr=${inpStr//[^0-9]/}
  # ="001"

Trim leading zeros

  inpStr=001
  newStr=$((10#$inpStr))
  # ="1"

Parse and trim leading zeros:

  inpStr=node001
  newStr=$((10#${inpStr//[^0-9]/}))
  # ="1"

# Execute script on file change
http://eradman.com/entrproject/
brew install entr
yum install entr

```sh
ls *.txt | entr [your command with -options]
```

## sed

Online editor
https://tio.run/#sed-gnu


## Tinc 1.1


```
yum install -y git gcc gcc-c++ glibc-devel make openssl-devel zlib-devel lzo-devel libncurses5-dev readline-devel
curl -L https://www.tinc-vpn.org/packages/tinc-1.1pre17.tar.gz > tinc-1.1.tar.gz
tar -xvf tinc-1.1.tar.gz
cd tinc-1.1pre17/
./configure
make
sudo make install
```

/usr/bin/mkdir -p '/usr/local/sbin'
/usr/bin/install -c tincd tinc '/usr/local/sbin'

  src/tincd
  src/tinc

/usr/bin/mkdir -p '/usr/local/share/info'
/usr/bin/install -c -m 644 ./tinc.info '/usr/local/share/info'

  doc/tinc.info

install-info --info-dir='/usr/local/share/info' '/usr/local/share/info/tinc.info'
/usr/bin/mkdir -p '/usr/local/share/man/man5'
/usr/bin/install -c -m 644 tinc.conf.5 '/usr/local/share/man/man5'

  doc/tinc.conf.5 

/usr/bin/mkdir -p '/usr/local/share/man/man8'
/usr/bin/install -c -m 644 tincd.8 tinc.8 tinc-gui.8 '/usr/local/share/man/man8'

  doc/tincd.8
  doc/tinc.8
  doc/tinc-gui.8


```
----- Failing vpn_ingr (master) -----
Connection from 95.216.218.148 port 52952
Got ID from <unknown> (95.216.218.148 port 52952): 0 worker101 17
No public key for worker101 specified!
Error while processing ID from worker101 (95.216.218.148 port 52952)
Closing connection with worker101 (95.216.218.148 port 52952)
Purging unreachable nodes
------ Slave ------
Trying to connect to ingress016 (95.216.185.23 port 762)
Connected to ingress016 (95.216.185.23 port 762)
Sending ID to ingress016 (95.216.185.23 port 762): 0 worker101 17
Sending 15 bytes of metadata to ingress016 (95.216.185.23 port 762)
Flushing 15 bytes to ingress016 (95.216.185.23 port 762)
Timeout from ingress016 (95.216.185.23 port 762) during authentication
Closing connection with ingress016 (95.216.185.23 port 762)
Could not set up a meta connection to ingress016
-------------------

------ Successful handshake (master) ------
Connection from 95.216.218.148 port 53082
Got ID from <unknown> (95.216.218.148 port 53082): 0 worker101 17
Sending ID to worker101 (95.216.218.148 port 53082): 0 etcd001 17
Sending 13 bytes of metadata to worker101 (95.216.218.148 port 53082)
Sending METAKEY to worker101 (95.216.218.148 port 53082): 1 429 672 0 0 38A61EFF6C720BB0131409C57E914126710E6B7AB65454BC90F3C96746BD936139234C45C43934FFC93424B9FAD319CEA0D6372A8A5E402A6A28D1044ED68385FA2E9DD6B7D2F8678A7917A467B73733E6F7D3B9D79E32950524CD827B0D9C0F99A2B6240F56393831939AD264C76DC5DDD583129EE00A4AC915B081D6A32D5373B7D2F6393A6ACD9EB079681E82CDD37D1EDF4DC197F4E66CCC3F8AE52439948DCE3BA0352FDD0DDB12A6CDE198E677701120956C665BA274DAF22E627F870C63E7045C5D52DA3184C97C1231879127F811231E2F7ABE23C9D76806AD89B5AF2F9C28C90A7675E28E085918E422D66CF233D2FEFF67FFDD05A00BF91B1F984470BE63DEF105FD88FEE14E49B4F9E9FEFE814CFBD0BC68F8A95CB937161D2E5705021355B37B85B56E6021889357075E82169B4D8D16D024FC63879E275762E6BA836B7D7880320A7C896C086760510CE337C8E7690CCB7C564B853EFF9F1C193AF2A6F28EF0496696389A1CE71BE255B3D487DB2BADBEF896AC158428C08EBA8759E92C2F83863C866B59CBB484C593F6CB1B88888C66E28CABECC633ABB738B1CB6B93FE1D54D23A0E1CA769DCB4F351FB8AE3A1C34FC3A957506382A12DE662FCD4021C977CDF8B19399A6D57D8D59DFE94890FC0476D283055BAC94E948E323577A1D1F7DA29E491842B73605C380F2A27B4D672355A4A3C3BD1909E9FC8
Sending 1039 bytes of metadata to worker101 (95.216.218.148 port 53082)
Flushing 1052 bytes to worker101 (95.216.218.148 port 53082)
Connection from 95.216.168.216 port 59178



----- Successful handshake (slave) ------
Trying to connect to etcd001 (95.216.185.119 port 760)
Connected to etcd001 (95.216.185.119 port 760)
Sending ID to etcd001 (95.216.185.119 port 760): 0 ingress016 17
Sending 16 bytes of metadata to etcd001 (95.216.185.119 port 760)
Flushing 16 bytes to etcd001 (95.216.185.119 port 760)
Got ID from etcd001 (95.216.185.119 port 760): 0 etcd001 17
Sending METAKEY to etcd001 (95.216.185.119 port 760): 1 429 672 0 0 0B727EB746BEAF0315F02017BBCED1ACCAF4B34482C4DE5BD1C13D0B3D6C754A136A6B60E16A6BDDBC5BB9038CEA91108CE16CD4BCCC602777FECDFA749A477AB9539B9BBDBA0A9440B42700354D0F6763CB6ACE84D32F7B5750C2B3721E4ACEF8F4CB6C401A2BAB55BF859E485D7B07D79C42C707201AD7C47D2B7B29D1A2CB98AFFA9E7FF09A74596D82408783F69311B1ADAC5904427DC9BD8CCBF4F44FFFF496DD77A94BBF8815D835AB3FA9E32BD3F717C1D64D7330151D9689280A1312E094F19853D40985E054951CC3EC8A924BB8C1FACFAD6D61C764AA6ABF98A530909C5E5F2DC49CB2D0DA3DE5F2ECFF6511EDDDE84A6520BCFECC48D8D8C1AEE54B7C738879DD6E8DCA1B23CA3AE199F1BF29D60C47D272DCABB075C76BCDE5B7C137E024E0EB89D71B68608FA09A37B199A5B42A36FEEAFACDC6E9328D714BD08B52644154F6E07241D27DD9B9E7D1EDAA25B968CB5D757D1BD166874D4D506934E64C41D01D03E22B57BC66EFB653E39B317102DFD5BBB536157800352EE69548316811F12618CB8A887F25B72071F3D5899163F71B91B1937DA1FC662B8030156138F6D89ED2D657E280AF54FC47D8D441CB7C991200D8F80FC5A3661B20A63ECFFFDAE51605AB26BDE5FC40DA2969B4B7B24F732332A5BF6E88057D76DA132D18ABF31D845748ED60BE77B0F63420FD8890983B142EE2BFA4CFE03CD96EFB
Sending 1039 bytes of metadata to etcd001 (95.216.185.119 port 760)
```


## Flannel as overlay network
While flannel was originally designed for Kubernetes, it is a generic overlay network that can be used as a simple alternative to existing software defined networking solutions.
https://coreos.com/flannel/docs/latest/running.html

curl -L https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz > flannel-v0.10.0-linux-amd64.tar.gz
tar -xvf flannel-v0.10.0-linux-amd64.tar.gz


### Simple vxlan network without encryption
etcdctl set /coreos.com/network/config '{ "Network": "10.5.0.0/16", "Backend": {"Type": "vxlan"}}'


### VPN network with Wireguard encryption
https://www.wireguard.com/

Still having issues with connectivity, appears to be firewall (iptables) https://github.com/coreos/flannel/issues/799

Check this, they show IP Tables stuff... https://nbsoftsolutions.com/blog/wireguard-vpn-walkthrough

```sh
etcdctl set /coreos.com/network/config <<'EOF'
{
  "Network": "10.5.0.0/16",
  "Backend": {
    "Type": "extension",
    "PreStartupCommand": "wg genkey | tee privatekey | wg pubkey",
    "PostStartupCommand": "export SUBNET_IP=`echo $SUBNET | cut -d'/' -f 1`; /usr/sbin/ip link del flannel-wg 2>/dev/null; /usr/sbin/ip link add flannel-wg type wireguard && wg set flannel-wg listen-port 51820 private-key privatekey && /usr/sbin/ip addr add $SUBNET_IP/32 dev flannel-wg && /usr/sbin/ip link set flannel-wg up && /usr/sbin/ip route add $NETWORK dev flannel-wg",
    "ShutdownCommand": "ip link del flannel-wg",
    "SubnetAddCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY endpoint $PUBLIC_IP:51820 allowed-ips $SUBNET",
    "SubnetRemoveCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY remove"
  }
}
EOF
```

### Get subnets from etcd
curl -s http://etcd001:2379/v2/keys/coreos.com/network/subnets | python -mjson.tool

### Check what ip-addr we are listening to
ip -4 a l

### Routing table
route && echo "---" && ip -4 a l

### Check connectivity
Can we ping host a from host b?

  Node A: ip -4 a l flannel.1
  Node B: ping 10.5.40.0

Can we send packets to host a from host b?

  Node A: nc -k -l 10.5.40.0 5000
  Node B: nc 10.5.40.0 5000 <<< "abc"


USE THIS TO DEBUG THE FLANNEL START UP COMMAND:
exports some variables to /root/outp
```sh
etcdctl set /coreos.com/network/config <<'EOF'
{
  "Network": "10.5.0.0/16",
  "Backend": {
    "Type": "extension",
    "PreStartupCommand": "wg genkey | tee privatekey | wg pubkey",
    "PostStartupCommand": "export SUBNET_IP=`echo $SUBNET | cut -d'/' -f 1`; echo \"$SUBNET_IP : $SUBNET | $NETWORK | $PUBLIC_IP\" > /root/outp; /usr/sbin/ip link del flannel-wg",
    "ShutdownCommand": "ip link del flannel-wg",
    "SubnetAddCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY endpoint $PUBLIC_IP:51820 allowed-ips $SUBNET",
    "SubnetRemoveCommand": "read PUBLICKEY; wg set flannel-wg peer $PUBLICKEY remove"
  }
}
EOF
```
```
/usr/local/sbin/flanneld -iface eth0 -public-ip 95.216.171.170 -etcd-endpoints http://etcd001:2379,http://etcd002:2379,http://etcd003:2379 && cat outp
```

### Check env vars
```bash
systemctl show [name-of-app]
# or for the running process
PID=<process_id> tr '\0' '\n' < /proc/$PID/environ
```

### Create user in db
```JavaScript
mongo --port 27017
use influencer
db.createUser({ user: "testuser", pwd: "testuser", roles: [ "readWrite", "dbAdmin" ] })
// db.createUser({ user: "testuser", pwd: "testuser", roles: [ { role: "readWrite", db: "influencer" }, { role: "dbAdmin", db: "influencer" } ] })
// db.createUser({ user: "testuser", pwd: "testuser", roles: [ { role: "readWrite", db: "admin" }, { role: "dbAdmin", db: "admin" } ] })
```

## etcd data model

```JavaScript
./app --cluster=cluster.cfg register-ingress --ingress=ingress_admin.cfg

ingress/
	[host.name.here:port]={
    publish: {
      port: 80,
      ssl: false,
      host_name: "ingress016.flstr.cloud"
    },
    location: [
      {
        location: "/",
        type: "frontend|backend",
        name: "[name]"
      }
    ]
  }
frontend/
	[name]/
		instance/
      [id]={ "node": "[name]", "ip": "123.23.23.0", "port": 123 }
    meta_data={
      publish: { ”port”: 5001 } // Used by HA proxy to expose service on worker nodes
      env_prefix: "[PREFIX]"
      env: { "PROTOCOL", "HOST", "PORT", "PATH" }
    }
backend/
	[name]/
		instance/
      [id]={ "node": "[name]", "ip": "123.23.23.0", "port": 123 }
    meta_data={
      publish: { ”port”: 5001 } // Used by HA proxy to expose service on worker nodes
      env_prefix: "[PREFIX]"
      env: { "PROTOCOL", "HOST", "PORT", "PATH" }
    }
service/
	[name]/
		instance/
      [id]={ "node": "[name]", "ip": "123.23.23.0", "port": 123 }
    meta_data={
      publish: { ”port”: 5001 } // Used by HA proxy to expose service on worker nodes
      env_prefix: "[PREFIX]"
      env: { "PROTOCOL", "HOST", "PORT", "PATH" }
    }
node/
  [id]={ "name": "[name]", "ip": "123.23.23.9", "services": ["service", "frontend", "backend"] }
```

## For each physcial node in the cluster
```bash
#!/bin/sh
##
## Register this node with etcd server
##
SERVICES='[% FOREACH s IN node.services %]"[% s %]"[%- ", " IF not loop.last %][% END %]'

registerNode() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/node/[% node.name %] \
    -XPUT -d value="{\"name\":\"[% node.name %]\", \"ip\":\"[% node.physical_ip %]\", \"services\": [ $SERVICES ]}" &>/dev/null
}

unregisterNode() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/node/[% node.name %]  -XDELETE &>/dev/null
}

if [ "$1" = "register" ]; then
  registerNode
  exit 0
fi

if [ "$1" = "unregister" ]; then
  unregisterNode
  exit 0
fi
```

## For each app (service|frontend|backend)
```bash
registerApp() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/[% app.type %]/[% app.name %]/meta_data \
    -XPUT -d value="$1" &>/dev/null
}
# registerService '{ "publish": { "ip": [% app.publish.ip %], "port": [% app.publish.port %] }, "env_prefix": "REDIS", "env": { "PROTOCOL": "[% app.env.protocol %]", "HOST": "[% app.env.host %]", "PORT": [% app.env.port %], "PATH": "[% app.env.path %]" }}'

unregisterApp() {
  # Todo: Check if empty
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/[% app.type %]/[% app.name %] -XDELETE &>/dev/null
}

registerAppInstance() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/[% app.type %]/[% app.name %]/instance/[% node.name %] \
    -XPUT -d value="$1" &>/dev/null
}
# registerAppInstance '{ "node": "worker101", "ip": "worker101", "port": 5000 }'

unregisterInstance() {
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/[% app.type %]/[% app.name %]/instance/[% node.name %]  -XDELETE &>/dev/null
}
```
