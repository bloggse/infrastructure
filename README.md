# Infrastructure
Build and maintain your own infrastructure and app-deployments through composable modules.

TODO: Improve documentation
TODO: Create status api and frontend 
TODO: Use etcd to select vpn_ctrl ip-addresses

## Example to create a cluster

Use the `./cli/cluster_example.cfg` and `./cli/app_config_examples` app-configurations as basis for your own app configurations.

```sh
./cluster --cluster=cluster.cfg create-ctrl --force
# If you need to fetch the vpn_ctrl keys in order to add new nodes without creating an etcd-cluster:
# ./cluster --cluster=cluster.cfg get-ctrl-vpn-keys

./cluster --cluster=cluster.cfg create-node --node-prefix=redis --nrof-nodes=2 --machine-type=cx21 --type=service --force
./cluster --cluster=cluster.cfg create-node --node-prefix=mongodb --nrof-nodes=3 --machine-type=cx21 --type=service --force
./cluster --cluster=cluster.cfg create-node --node-prefix=worker --nrof-nodes=4 --machine-type=cx21 --type=worker --force

./cluster --cluster=cluster.cfg create-node --node-prefix=ingress --nrof-nodes=1 --machine-type=cx21 --type=ingress --force

./app --cluster=cluster.cfg deploy-app --app=app_config/dynomite-redis.cfg --target="redis051,redis052"
./app --cluster=cluster.cfg deploy-app --app=app_config/mongodb_cluster.cfg --target="mongodb053,mongodb054,mongodb055"

# Generate SSL-certs before activating ingress rules
# -k accepts self signed certificates 
curl -k https://ingress016.[enter CLUSTER_DOMAIN]

# Create DB users
./app --cluster=cluster.cfg create-mongo-user --target="mongodb053,mongodb054,mongodb055" --db-username=testuser --db-password=testuser --db-name=testdb
# TODO: Register user somewhere

# Install some apps
./app --cluster=cluster.cfg deploy-app --app=app_config/app_api.cfg --target="worker101,worker102"
./app --cluster=cluster.cfg deploy-app --app=app_config/app_front.cfg --target="worker103,worker104"

./app --cluster=cluster.cfg register-ingress --ingress=app_config/ingress016.cfg
```

## Example to tear down a cluster

```sh

# If you want to remove apps or ingress:
./app --cluster=cluster.cfg unregister-ingress --ingress=app_config/ingress016.cfg

./app --cluster=cluster.cfg remove-app --app=app_config/app_front.cfg --target="worker103,worker104"
./app --cluster=cluster.cfg remove-app --app=app_config/app_api.cfg --target="worker101,worker102"

# To remove all the nodes:
./cluster --cluster=cluster.cfg destroy-node --node-prefix=ingress --force
./cluster --cluster=cluster.cfg destroy-node --node-prefix=worker --force
./cluster --cluster=cluster.cfg destroy-node --node-prefix=mongodb --force
./cluster --cluster=cluster.cfg destroy-node --node-prefix=redis --force

./cluster --cluster=cluster.cfg destroy-ctrl --force
```

## Checklist
- VPN (tinc) up
  - interface
  - can ping others
  - firewall settings
- public facing firewall is up
- nmap to check other hosts open ports

### Check if communication works

Server instance: node001
```
$ nc -l -p 5000
```

Server instance: node002
```
$ echo "abc" | nc node001 5000
```

nc -l -p 5000 -s 10.5.60.1
echo "abc" | nc 10.5.60.1 5000

The first node should print "abs"

### Peel the onion troubleshooting

1, network
- on node: ping controller001 # vpn_ctrl working
- on node: ping [consuming###] # vpn_srvc or vpn_ingr working
2, firewall
- on consuming node: ping [node###] # no blocking firewall and DNS working
3, application on node
- check health on local node
4, application in cluster
- check etcd entry (backend or ingress)
- check health from consuming machine
5, loadbalancer on node
- check /etc/haproxy/haproxy.cfg
- check /etc/hosts
- check /etc/cluster/backend_services.env
6, ingress
- on node: ping controller001 # vpn_ctrl working
- on consuming node: ping [node###] # no blocking firewall and DNS working
- check etcd entry (backend or ingress)


1, Subsystem
2, Name
3, Actual test
4, Actions on failed test
5, Troubleshooting guide/notes

## Nginx for microservices
https://hagbarddenstore.se/posts/2016-03-11/using-nginx-to-load-balance-microservices/

## etcd
Check cluster health:

```sh
$ etcdctl cluster-health
$ etcdctl member list
```

```sh
$ ETCDCTL_API=3 etcdctl put foo bar
$ ETCDCTL_API=3 etcdctl get foo
```

1. Create confd install through shared
2. Add overlay
3. Start confd service

Configuring the cluster:
https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/clustering.md

ETCD_AUTO_TLS=true
ETCD_PEER_AUTO_TLS=true

confd
https://github.com/kelseyhightower/confd/blob/master/docs/template-resources.md
https://github.com/kelseyhightower/confd/blob/master/docs/templates.md

Example RPM package for confd
https://github.com/michaeltchapman/confd-rpm

# HA Proxy
Let's encrypt
https://www.haproxy.com/blog/lets-encrypt-acme2-for-haproxy/

## Tinc
You don't need multiple networks unless you want isolation
https://www.tinc-vpn.org/pipermail/tinc/2017-May/004823.html


Connect to controller_overlay
1. Define IP-range for service
2. Generate key files for service
3. Copy key files for service machines to controllers
4. Copy key files for controller machines to service

Only hosts with public key files exchanged can maintain a direct connection
https://www.tinc-vpn.org/pipermail/tinc/2013-January/003132.html 

## Firewalld
Required reading on Firewalld:
https://www.linode.com/docs/security/firewalls/introduction-to-firewalld-on-centos/

https://www.linuxjournal.com/content/understanding-firewalld-multi-zone-configurations

When changing settings:
https://www.linode.com/docs/security/firewalls/introduction-to-firewalld-on-centos/#configuration-sets

Reeference:
https://firewalld.org/documentation/man-pages/firewall-cmd.html


## Debug network connection
```sh
printf "\n--- ---\n\n"
cat /etc/hosts
printf "\n--- ---\n\n"
ip link show
printf "\n--- Routes out ---\n\n"
route
printf "\n--- Local IPs ---\n\n"
ip -4 a|grep inet
printf "\n--- ---\n\n"
firewall-cmd --get-active-zones
printf "\n--- ---\n\n"
firewall-cmd --list-all
printf "\n--- ---\n\n"
firewall-cmd --zone=vpn --list-all
```

curl -s http://etcd001:2379/v2/keys/coreos.com/network/subnets | python -mjson.tool

### Commands
Get active firewall zones

  firewall-cmd --get-active-zones

Check active firewall settings

  firewall-cmd --list-all
  firewall-cmd --zone=vpn --list-all

Find firewall service settings

  $ grep ssh /etc/services
  $ grep tinc /etc/services

Start and stop firewall

  service firewalld stop
  service firewalld start

Reload firewall settings

  firewall-cmd --reload

Check network interfaces:

  ip link show

Add a runtime setting (not permanent)

  firewall-cmd --add-service=elasticsearch
  firewall-cmd --remove-service=elasticsearch

  firewall-cmd --zone=public --add-port=5000/tcp
  firewall-cmd --zone=limited --add-port=6443/tcp

Add a permanent setting (requires reeload/restart)

  firewall-cmd --permanent --add-service elasticsearch

curl http://localhost:9200/_cluster/health

https://www.rootusers.com/how-to-use-firewalld-rich-rules-and-zones-for-filtering-and-nat/

## Debug service

```sh
echo "*************** etcd should contain a service ***************"
./infrastructure cmd controller001 "etcdctl ls '/services'" | grep "redis"
echo "*************** etcd should contain service nodes ***************"
./infrastructure cmd controller001 "etcdctl ls '/services/redis/nodes'"
echo "*************** /etc/haproxy/haproxy.cfg should contain a service and nodes ***************"
./infrastructure cmd nodejs001 "cat /etc/haproxy/haproxy.cfg" | grep "redis"
echo "*************** /etc/hosts should contain nodes with vpn ips ***************"
./infrastructure cmd nodejs001 "cat /etc/hosts" | grep "redis"
echo "*************** /etc/cluster/backend_services.env should contain service vars ***************"
./infrastructure cmd nodejs001 "cat /etc/cluster/backend_services.env" | grep "REDIS_"
```

## Debug elasticsearch
./cluster --cluster=cluster.cfg cmd --target=elasticsearch001 "curl -s http://host:9200"
./cluster --cluster=cluster.cfg cmd --target=elasticsearch001 "curl -s http://host:9200/_cluster/health"

./cluster --cluster=cluster.cfg cmd --target=elasticsearch002 "curl -s http://host:9200"
./cluster --cluster=cluster.cfg cmd --target=elasticsearch002 "curl -s http://elasticsearch001:9200"

./cluster --cluster=cluster.cfg cmd --target=elasticsearch001 "service firewalld stop"
./cluster --cluster=cluster.cfg cmd --target=elasticsearch002 "curl -s http://elasticsearch001:9200"
./cluster --cluster=cluster.cfg cmd --target=elasticsearch001 "service firewalld start"
