#!/bin/bash
## Load variables to use in this script
INIT_PHASE="1_install"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Install OpenRESTY"
if isLinux centos; then
  if [ ! -f /etc/yum.repos.d/openresty.repo ]; then
    curl -Lo /etc/yum.repos.d/openresty.repo https://openresty.org/package/centos/openresty.repo &>$_mute_
    pkg update &>$_mute_
  fi
  pkg -y install lua-devel unzip openresty openresty-resty gcc &>$_mute_

elif isLinux debian; then
  if [ ! -f /etc/apt/sources.list.d/openresty.list ]; then
    wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add - &>$_mute_
    echo "deb http://openresty.org/package/debian $(lsb_release -sc) openresty" > /etc/apt/sources.list.d/openresty.list
    pkg update &>$_mute_
  fi

  pkg install -y lua5.3 liblua5.3-dev unzip openresty &>$_mute_
fi

adduser --system --no-create-home --group $NGINX_USER &>$_mute_

if ! hash luarocks 2>$_mute_; then
  printf "install luarocks... "
  mkdir -p output
  cd output
  curl -O -J -L https://luarocks.org/releases/luarocks-3.0.4.tar.gz &>$_mute_
  tar zxpf luarocks-3.0.4.tar.gz &>$_mute_
  (cd luarocks-3.0.4 && ./configure &>$_mute_; make bootstrap &>$_mute_)
  cd ..
fi

luarocks show lua-resty-auto-ssl &>$_mute_
if [[ $? != 0 ]]; then
  printf "install lua-resty-auto-ssl... "
  luarocks install lua-resty-auto-ssl &>$_mute_
fi
