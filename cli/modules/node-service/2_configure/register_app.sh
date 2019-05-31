#!/bin/bash

for i in "$@"; do
  case $i in
    -t=*|--type=*)
    TYPE="${i#*=}"
    shift # past argument=value
    ;;
    -n=*|--name=*)
    NAME="${i#*=}"
    shift # past argument=value
    ;;
    -v=*|--value=*)
    VALUE="${i#*=}"
    shift # past argument=value
    ;;
    *)
      if [[ "register-app unregister-app get-app-instances register-app-instance unregister-app-instance update-sytemd-unit" == *"${i}"* ]]; then
        CMD="${i}"
      fi
    ;;
  esac
done

if [ "$CMD" = "register-app" ]; then
  # Usage: registerApp frontend influcener_crm '{ "publish": { "ip": [% app.publish.ip %], "port": [% app.publish.port %] }, "env_prefix": "REDIS", "env": { "PROTOCOL": "[% app.env.protocol %]", "HOST": "[% app.env.host %]", "PORT": [% app.env.port %], "PATH": "[% app.env.path %]" }}'
  [ -z $TYPE ] && echo "Missing param --type" && exit -1
  [ -z $NAME ] && echo "Missing param --name" && exit -1
  [ -z "$VALUE" ] && echo "Missing param --value" && exit -1

  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME/meta_data \
    -XPUT -d value="$VALUE" &>/dev/null
fi

if [ "$CMD" = "unregister-app" ]; then
  # Usage: unregisterApp frontend influcener_crm
  [ -z $TYPE ] && echo "Missing param --type" && exit -1
  [ -z $NAME ] && echo "Missing param --name" && exit -1
  
  if [ -z "`curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME/instance/ | jq '.node.nodes[] | .key'`" ]
  then
    curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME -XDELETE &>/dev/null
  fi
fi

if [ "$CMD" = "get-app-instances" ]; then
  # Usage: registerAppInstance frontend influcener_crm '{ "node": "worker101", "ip": "worker101", "port": 5000 }'
  [ -z $TYPE ] && echo "Missing param --type" && exit -1
  [ -z $NAME ] && echo "Missing param --name" && exit -1

  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME/instance/ | jq '.node.nodes[] | .key'
fi

if [ "$CMD" = "register-app-instance" ]; then
  # Usage: registerAppInstance frontend influcener_crm '{ "node": "worker101", "ip": "worker101", "port": 5000 }'
  [ -z $TYPE ] && echo "Missing param --type" && exit -1
  [ -z $NAME ] && echo "Missing param --name" && exit -1
  [ -z "$VALUE" ] && echo "Missing param --value" && exit -1

  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME/instance/[% node.name %] \
    -XPUT -d value="$VALUE" &>/dev/null
fi

if [ "$CMD" = "unregister-app-instance" ]; then
  # Usage: unregisterAppInstance frontend influcener_crm
  [ -z $TYPE ] && echo "Missing param --type" && exit -1
  [ -z $NAME ] && echo "Missing param --name" && exit -1
  
  curl -L http://[% etcd.vpn_ip %]:[% etcd.port %]/v2/keys/$TYPE/$NAME/instance/[% node.name %] -XDELETE &>/dev/null

  # TODO: If last instance, remove service completely
fi
