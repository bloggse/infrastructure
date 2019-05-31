#!/bin/bash

_mute_=/dev/null

_bld="\033[1m"
bld_="\033[21m"
_blk_="\033[30m"
_red_="\033[31m"
_grn_="\033[32m"
_ylw_="\033[33m"
_dim="\033[2m"
dim_="\033[22m"
printfGreen() {
  printf "\e[32m$1\e[30m"
}

echoErr() {
  echo -e "${_red_}${dim_}[install error]${_dim}${_blk_} $1"
  
  echo "`date` [$INIT_MODULE] [install error] $1" >> $HOME/output/install_err.log
}
mkdir -p $HOME/output; touch $HOME/output/install_err.log
echo "`date` [$INIT_MODULE] [new run] ---------------------------------------" >> $HOME/output/install_err.log

echoStep() {
  # Usage: echoStep "This is a step"
  local _line_='----------------------------------------'
  local _space_='         '

  printfGreen "${dim_}$NODE_NAME"
  echo -e "${_space_:${#NODE_NAME}} $1 "
  printf "${_dim}"
}

waitForServer() {
  # Usage: waitForServer node001
  SERVER=$1

  printf "Waiting for ping from $1... "
  n=0
  while ! ping -c 1 -n -W 1 $SERVER &> /dev/null; do
      printf "%c" "."
      # If more than 30 tries then exit function
      n=$(( $n + 1 )); [[ $n > 30 ]] && kill -INT $$;
  done
  echo "!"
}

isLinux() {
  # Usage: if isLinux centos; then echo "centos"; fi
  if cat /etc/os-release | grep ^ID=.*$1.* &>/dev/null; then
    true
  else
    false
  fi
}

########################
# Cross-platform stuff #
########################

waitForApt() {
  printf "Wait for apt-get"
  while [ -a /var/lib/dpkg/locka ]
  do
    printf "."
    sleep 1
  done
  echo "!"
}

pkg() {
  # Usage: pkg install -y your-package
  local pkgCmd
  if hash yum &>/dev/null; then 
    pkgCmd=yum
  elif hash apt-get &>/dev/null; then
    waitForApt
    pkgCmd=apt-get
  fi

  $pkgCmd "$@"
}

upsertLine() {
  local filePath=$1
  local newStr=$2
  local regex=$3

  [ -z "$filePath" ] && echo "Missing \$1 param filePath" && exit -1
  [ -z "$newStr" ] && echo "Missing \$2 param newStr" && exit -1

  if [ ! -z "$regex" ]
  then # Update existing line in file
    sed -i "s/$regex/$newStr/g" $filePath
  fi

  if ! grep "$newStr" $filePath
  then # Or append an entry to end of file
    echo "$newStr" >> $filePath
  fi
}

retryUntilSuccess() {
  while ! $1 &>$_mute_
  do 
    printf "."
    sleep 1
  done
  echo "!"
}