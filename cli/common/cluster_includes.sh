#!/bin/bash
CURR_PATH="$(cd "$(dirname "$0")" && pwd)"
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SSH_OPTS="-o StrictHostKeyChecking=no"
CR=$'\n'

confirm() {
    # Usage
    # confirm || (echo "Good bye!" && exit -1)
    # confirm && echo "That was a yes!"
    # confirm "Your question? [y/N]" || echo "That was a no..."
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

installPkgs() {
  ssh -i ~/.ssh/$SSH_KEY_NAME root@$1.$DOMAIN $SSH_OPTS "PKGS=\"$2\" bash -s " < $THIS_DIR/scripts/remote_install_packages.sh &> /dev/null
}

installPython() {
  for i in `seq 1 $NROF_NODES`; do
    # TODO: Do in parallell?
    NODE="$NODE_PREFIX`printf %03d $i`"
    printf "Installing python on $NODE..."
    installPkgs $NODE "python-minimal python-simplejson"
    echo " done!"
  done
}

# -----------------------------------------------------------------------------------------------
waitForServers() {
  SERVERS=$1
  printf "Waiting for ssh on newly created servers to be available... "
  IFS=$'\n'
  for TMP in `hcloud server list | grep $NODE_PREFIX` ; do
    IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP

    printf "$NAME "

    # If the server was just created, start with ping
    if [[ $SERVERS == *"$NAME"* ]]; then
      while ! ping -c 1 -n -W 1 $MASTER_IPV4 &> /dev/null; do
          printf "%c" "."
      done
    fi

    # Then check ssh for both new and old servers
    EXIT_CODE=255
    while [ "$EXIT_CODE" = "255" ]; do
        sleep 1
        printf "%c" ":"
        ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$MASTER_IPV4 $SSH_OPTS exit
        # Get exit code from last command
        EXIT_CODE="$?"
    done
    printf " "  
  done
  echo ">> SSH running on all hosts!"
}

# -----------------------------------------------------------------------------------------------
generateNodeName() {
  ###
  ### TODO: This should be done by asking etcd-cluster
  ###
  case $TYPE in
    worker)
    n=$(( $1 + 100 ))
    ;;
    service)
    n=$(( $1 + 50 ))
    ;;
    ingress)
    n=$(( $1 + 15 ))
    ;;
    test)
    n=$(( $1 + 200 ))
    ;;
    *)
    # controller
    n=$1
  esac

  # n=${1//[!0-9]/} # convert to number
  n=$((10#$n)) # Remove leading zero

  # Loop until no conflict
  for _t_ in `ls .hosts`; do str="$str $_t_"; done
  test=$(printf %03d $n)

  while [[ "$str" == *"$test"* ]] && [[ "$str" != *"$NODE_PREFIX$test"* || "$REBUILD" == "" ]]; do
    n=$(($n + 1))
    test=$(printf %03d $n)
  done

  outp="$NODE_PREFIX`printf %03d $n`"
}

# -----------------------------------------------------------------------------------------------
createNodes() {
  local start_at=1; [ ! -z $1 ] && start_at=$1
  local nrof_nodes=$NROF_NODES; [ ! -z $2 ] && nrof_nodes=$2

  # Add project context
  if ! hcloud context list | grep -q "$PROJECT_CONTEXT"; then
    hcloud context create $PROJECT_CONTEXT
  fi

  # Select project context
  if ! hcloud context active | grep -q "$PROJECT_CONTEXT"; then
    hcloud context use $PROJECT_CONTEXT
  fi

  # Check ssh-keys
  if ! hcloud ssh-key describe $SSH_KEY_NAME 1>/dev/null; then
    hcloud ssh-key create --name $SSH_KEY_NAME --public-key-from-file $HOME/.ssh/$SSH_KEY_NAME.pub
  fi

  echo "************* PROCESSING NODES [ $start_at..$nrof_nodes ] *************"
  ##
  ## 1. Find existing nodes by checking hcloud server list
  IFS=$'\n'
  for TMP in `hcloud server list | grep $NODE_PREFIX` ; do
    IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP
  
    if [ -z "${EXISTING_SERVERS}" ]; then
      EXISTING_SERVERS="$NAME"
    else
      EXISTING_SERVERS="${EXISTING_SERVERS} $NAME"
    fi
    echo "Node: $NAME.$DOMAIN exists! :)"
    start_at=$((start_at + 1))
  done

  NEW_SERVERS=""
  if (( "$start_at" <= "$nrof_nodes" )); then
    IFS=$'\n'
    for i in `seq $start_at $nrof_nodes`; do
      generateNodeName "$i"; NAME=$outp
      # Create an entry to make sure we get unique numbers
      mkdir -p .hosts/$NAME

      if [ -z "${NEW_SERVERS}" ]; then
        NEW_SERVERS="$NAME"
      else
        NEW_SERVERS="${NEW_SERVERS} $NAME"
      fi
      echo "Node: $NAME.$DOMAIN doesn't exist, creating now:"
      hcloud server create --name $NAME --image $SERVER_OS --type $MACHINE_TYPE --ssh-key $SSH_KEY_NAME --location $LOCATION &
    done
    wait
  fi
}

# -----------------------------------------------------------------------------------------------
rebuildNodes() {
  # Select project context
  if ! hcloud context active | grep -q "$PROJECT_CONTEXT"; then
    hcloud context use $PROJECT_CONTEXT
  fi
  
  echo "************* REBUILDING NODES *************"
  NEW_SERVERS=""
  IFS=$'\n'
  for TMP in `hcloud server list | grep $NODE_PREFIX` ; do
    IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP
    echo "Rebuilding $NAME"
    hcloud server rebuild $NAME --image $SERVER_OS &
    if [ -z "$NEW_SERVERS" ]; then
      NEW_SERVERS=${NAME}
    else
      NEW_SERVERS="${NEW_SERVERS} ${NAME}"
    fi
  done
  wait $(jobs -p)
}

# -----------------------------------------------------------------------------------------------
destroyNodes() {
  NODES_TO_DELETE=$1
  # echo "$NODES_TO_DELETE"
  [ ! confirm ] && exit -1

  # Select project context
  hcloud context use $PROJECT_CONTEXT

  destroyed_nodes=""
  IFS=$'\n'
  for NAME in $NODES_TO_DELETE; do
    printfGreen "$NAME"
    hcloud server delete $NAME
    [ ! -z "$destroyed_nodes" ] && destroyed_nodes="$destroyed_nodes "
    destroyed_nodes="${destroyed_nodes}$NAME"
  done

  printf "Cleaning up local data... "
  IFS=' '
  for node in $destroyed_nodes; do
    printf "«"; printfGreen "$node"; printf "»"
    rm -rf $THIS_DIR/.hosts/${node}
  done
  echo " done!"

  OUTP=$destroyed_nodes
}

# -----------------------------------------------------------------------------------------------
removeFromCtrl() {
  NODES_TO_DELETE=$1
  [ ! confirm ] && exit -1
  printf "Removing: $NODES_TO_DELETE from controller plane [ "
  CTRL_NODES="${CTRL_PREFIX}001 ${CTRL_PREFIX}002 ${CTRL_PREFIX}003"

  IFS=' '
  for ctrl_node in $CTRL_NODES; do
    printfGreen "\n$ctrl_node "
    # TODO: This isn't iterating over all lines in list, why is that? IFS not working?
    # Perhaps remove quotes around "$NODES_TO_DELETE"
    remote_script="#!/bin/bash"
    IFS=$'\n'
    for node in "$NODES_TO_DELETE"; do
      printf "$node "
      read -r -d '' remote_script <<-EOF
$remote_script
sed -i '/^21.0.0.[0-9]* $node$/D' /etc/hosts
rm -f "/etc/tinc/vpn_ctrl/hosts/$node"
EOF
    done
    ssh -i $HOME/.ssh/$SSH_KEY_NAME root@$ctrl_node.$DOMAIN $SSH_OPTS "$remote_script" &>/dev/null
  done
  echo "]"

}

# -----------------------------------------------------------------------------------------------
registerDNS() {
  
  IFS=$'\n'
  for TMP in `hcloud server list | grep $NODE_PREFIX` ; do
    IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP
    
    # Add DNS entry [ ! -z "$1" ] || 
    if [ -z "$1" ] || [[ "$1" == *"$NAME"* ]]; then
      echo "Creating DNS entry for $NAME.$DOMAIN"
      now dns add $DOMAIN $NAME A $MASTER_IPV4 &>/dev/null
    else
      echo "DNS entry exists for $NAME.$DOMAIN"
    fi
  done
  # wait

  now dns ls $DOMAIN | grep $NODE_PREFIX
}

# -----------------------------------------------------------------------------------------------
deregisterDNS() {
  NODES_TO_DEREG=$1
  [ ! confirm ] && exit -1
  
  IFS=$'\n'
  for ROW in $NODES_TO_DEREG; do
    IFS=' ' read ID NAME <<< $ROW
    # Remove DNS entries
    #export RESPONSE=`curl -s "https://api.zeit.co/v2/domains/$DOMAIN/records" -H "Authorization: Bearer $ZEIT_TOKEN"` 

    # echo $RESPONSE
    #export RECORD_ID=`echo $RESPONSE | jq --arg master_ip $MASTER_IPV4 -r '.records[] | select(.value==$master_ip) | .id'`
    
    # echo "$RECORD_ID"
    echo "Removing DNS entry for $NAME.$DOMAIN ($ID)"
    echo "y" | now dns rm $ID &>/dev/null
  done
  # wait
  
  now dns ls $DOMAIN
}


_bld="\033[1m"
bld_="\033[21m"
_blk_="\033[30m"
_red_="\033[31m"
_grn_="\033[32m"
_ylw_="\033[33m"
_dim="\033[2m"
dim_="\033[22m"
_clr_="\033[0m"
printfGreen() {
  printf "\e[32m$1\e[30m"
}

# -----------------------------------------------------------------------------------------------
getServerId() {
  local node_name
  if [ -z "$1" ]; then
    generateNodeName 1; node_name=$outp
  else
    node_name=$1
  fi

  local TMP=`hcloud server list | grep $node_name`
  local ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER
  IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP
  
  outp="$ID"
}

# -----------------------------------------------------------------------------------------------
getImageName() {
  local hash=$1

  local TMP=`hcloud image list -l hash=$hash | grep snapshot`

  local ID TYPE NAME DESCRIPTION
  IFS=' ' read ID TYPE NAME DESCRIPTION <<< $TMP
  
  outp="$ID"
}

# -----------------------------------------------------------------------------------------------
renderTemplatesForNode() {
  local module=$1
  local init_phase=$2
  local node=$3

  local tmp_server_list=`hcloud server list | grep $NODE_PREFIX`
  local ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER
  IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< `grep "$node" <<< $tmp_server_list`
  NODE_PHYSICAL_IP=$MASTER_IPV4

  if [ -f $THIS_DIR/modules/$module/host_data.sh ]; then
    source $THIS_DIR/modules/$module/host_data.sh
    generateHostData $node $module $init_phase > $THIS_DIR/.hosts/${node}/$module/host.data
  else
    cat '# No host.data file in this module' > $THIS_DIR/.hosts/${node}/$module/host.data
  fi
  
  ttree --colour --pre_chomp --absolute --recurse \
    --pre_process=$THIS_DIR/.hosts/${node}/$module/host.data \
    --src=$THIS_DIR/modules/$module/$init_phase \
    --dest=$THIS_DIR/.hosts/${node}/$module/$init_phase  &>/dev/null
}

# -----------------------------------------------------------------------------------------------
runInitPhase() {
  local init_modules=$1
  local init_phase
  
  echo ""
  echo "________________ Now initialising templates etc. ________________"
  echo ""

  # 1. Stage the phase by running templates in folder if it exists
  IFS=' '
  for module in $init_modules; do
    printf "[staging] $module "
    IFS=' '
    for node in $NEW_SERVERS; do
      printf "«"; printfGreen "$node"; printf "»"
      mkdir -p $THIS_DIR/.hosts/${node}/$module

      mkdir -p $THIS_DIR/.hosts/${node}/$module/common
      # Link common resource files
      ln -fs $THIS_DIR/common/* $THIS_DIR/.hosts/${node}/$module/common/ &>/dev/null
      # and render the common directory...
      renderTemplatesForNode $module common $node

      for init_phase in 1_install 2_configure 3_integration 4_post_integration_configure 99_teardown; do
        if [ -f $THIS_DIR/modules/$module/$init_phase.sh ]
        then
          ln -fs $THIS_DIR/modules/$module/$init_phase.sh $THIS_DIR/.hosts/${node}/$module/$init_phase.sh &>/dev/null
        fi

        if [ -d $THIS_DIR/.hosts/${node}/$module/$init_phase ]
        then
          # Clear target directory
          rm -rf $THIS_DIR/.hosts/${node}/$module/$init_phase &>/dev/null
        fi

        if [ -d $THIS_DIR/modules/$module/$init_phase ]; then
          mkdir -p $THIS_DIR/.hosts/${node}/$module/$init_phase
          # Link binary files
          if [ -d "$THIS_DIR/modules/$module/$init_phase/bin" ]; then
            mkdir -p $THIS_DIR/.hosts/${node}/$module/$init_phase/bin
            ln -fs $THIS_DIR/modules/$module/$init_phase/bin/* $THIS_DIR/.hosts/${node}/$module/$init_phase/bin/
          fi
          # Then render templates
          renderTemplatesForNode $module $init_phase $node
        fi
      done
    done
    echo " done!"
  done
}

# -----------------------------------------------------------------------------------------------
rsyncTemplates() {
  local _module=$1
  local _servers=$2
  local node

  # echo "DEBUG: $_servers"
  printf "[rsync] "
  IFS=' '
  for node in $_servers; do
    printf "«"; printfGreen "$node"; printf "»"
    ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$node.$DOMAIN $SSH_OPTS "hash rsync || apt-get install -y rsync || yum install -y rsync" &>/dev/null
    rsync -Lavz --no-owner --no-group -e "ssh -i $HOME/.ssh/$SSH_KEY_NAME $SSH_OPTS" $THIS_DIR/.hosts/${node}/$_module root@$node.$DOMAIN:/root/ &>/dev/null &
  done
  wait
  echo " done!"
}

runModulesInstall() {
  local init_modules=$1
  local init_phase="1_install"
  local module node
  
  # 1. Install
  echo ""
  echo "________________ Now running INSTALL phase for all modules ________________"
  echo ""
  IFS=' '
  for module in $init_modules; do

    # Rsync all files to remote on each iteration because templates can change
    rsyncTemplates $module "$NEW_SERVERS"; wait

    # 2. Execute script on deploy machine in staging directory
    echo -e "[executing script] ${_bld}${module}${bld_} "
    IFS=' '
    for node in $NEW_SERVERS; do
      printf "${_dim}"
      if [ -h "$THIS_DIR/.hosts/${node}/$module/$init_phase.sh" ]
      then
        ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$node.$DOMAIN $SSH_OPTS "(cd $module && /bin/bash $init_phase.sh)" &
      else
        echo -e "${_dim}- no action specified -${dim_}"
      fi
    done
    wait # Wait for each module to complete so we avoid race conditions
    printf "${_clr_}"
  done

}

runModulesConfigure() {
  local init_modules=$1
  local init_phase module node

  echo ""
  echo "________________ Now running configuration phases for all modules ________________"
  echo ""
  IFS=' '
  for module in $init_modules; do
    echo -e "${_bld}*** $module ***${bld_}"
    # Rsync all files to remote on each iteration because templates can change
    rsyncTemplates $module "$NEW_SERVERS"; wait

    init_phase="2_configure"
    echo ""
    echo "- $init_phase:"

    IFS=' '
    for node in $NEW_SERVERS; do
      printf "${_dim}"
      if [ -h "$THIS_DIR/.hosts/${node}/$module/$init_phase.sh" ]
      then
        ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$node.$DOMAIN $SSH_OPTS "(cd $module && /bin/bash $init_phase.sh)" &
      else
        echo -e "${_dim}- no action specified -${dim_}"
      fi
    done
    wait # Wait for each module to complete so we avoid race conditions
    printf "${_clr_}"

    init_phase="3_integration"
    echo ""
    echo "- $init_phase:"

    IFS=' '
    for node in $NEW_SERVERS; do
      printf "${_dim}"
      if [ -h "$THIS_DIR/.hosts/${node}/$module/$init_phase.sh" ]
      then
        (cd "$THIS_DIR/.hosts/${node}/$module" && /bin/bash "$init_phase.sh")
      else
        echo -e "${_dim}- no action specified -${dim_}"
      fi
      printf "${_clr_}"
    done

    init_phase="4_post_integration_configure"
    echo ""
    echo "- $init_phase:"

    IFS=' '
    for node in $NEW_SERVERS; do
      printf "${_dim}"
      if [ -h "$THIS_DIR/.hosts/${node}/$module/$init_phase.sh" ]
      then
        ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$node.$DOMAIN $SSH_OPTS "(cd $module && /bin/bash $init_phase.sh)" &
      else
        echo -e "${_dim}- no action specified -${dim_}"
      fi
    done
    wait # Wait for each module to complete so we avoid race conditions
    printf "${_clr_}"
    echo ""
  done
}

runModulesTeardown() {
  local init_modules=$1
  local servers=$2
  local init_phase module node

  echo ""
  echo "________________ Now running teardown phases for all modules ________________"
  echo ""
  IFS=' '
  for module in $init_modules; do
    echo -e "${_bld}*** $module ***${bld_}"
    # Rsync all files to remote on each iteration because templates can change
    rsyncTemplates $module "$servers"; wait

    init_phase="99_teardown"
    echo ""
    echo "- $init_phase:"

    IFS=' '
    for node in $servers; do
      printf "${_dim}"
      if [ -h "$THIS_DIR/.hosts/${node}/$module/$init_phase.sh" ]
      then
        ssh -q -i ~/.ssh/$SSH_KEY_NAME root@$node.$DOMAIN $SSH_OPTS "(cd $module && /bin/bash $init_phase.sh)" &
      else
        echo -e "${_dim}- no action specified -${dim_}"
      fi
    done
  done
}

checkForceInit() {
  local start_at=1

  if [ ! -z $FORCE_INIT ]; then
    NEW_SERVERS=""

    IFS=$'\n'
    for TMP in `hcloud server list | grep $NODE_PREFIX` ; do
      IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP

      start_at=$(( $start_at + 1 ))
    
      if [ -z "$NEW_SERVERS" ]; then
        NEW_SERVERS="$NAME"
      else
        NEW_SERVERS="${NEW_SERVERS} $NAME"
      fi
    done
  
    if (( "$start_at" <= "$NROF_NODES" )); then
      IFS=$'\n'
      for i in `seq $start_at $NROF_NODES`; do
        # Add space
        [ ! -z "$NEW_SERVERS" ] && NEW_SERVERS="${NEW_SERVERS} "
        # Add node name
        generateNodeName "$i"; node=$outp
        NEW_SERVERS="${NEW_SERVERS}$node"
      done
    fi
  fi
}

getListOfServerNodes() {
  local _prefix=$1

  outp=""
  IFS=$'\n'
  for TMP in `hcloud server list | grep $_prefix` ; do
    IFS=' ' read ID NAME STATUS MASTER_IPV4 MASTER_IPV6 DATACENTER <<< $TMP
    [ ! -z "$outp" ] && outp="${outp}$CR"
    outp="${outp}$NAME"
  done
  echo "$outp"
}

getListOfDNSEntries() {
  local _prefix=$1

  outp=""
  IFS=$'\n'
  for TMP in `now dns ls | grep $_prefix` ; do
    IFS=' ' read ID NAME TYPE IPV4 TIME <<< $TMP
    [ ! -z "$outp" ] && outp="${outp}$CR"
    outp="${outp}$ID $NAME"
  done
}

createClusterNode() {
  NODE_TYPE=$1
  INIT_MODULES="$2"

  echo -e "${_clr_}${_ylw_}${_bld}"
  echo -e "Creating [$NODE_TYPE]"
  echo -e "with modules [$INIT_MODULES]"
  echo -e "${_clr_}"

  # 1. Create nodes from OS image or snapshot. Store a new snapshot if specified with CREATE_SNAPSHOT

  # Calculate checksum on all modules install.sh and install/
  # https://stackoverflow.com/questions/545387/linux-compute-a-single-hash-for-a-given-folder-contents
  local tmp
  for module_path in $INIT_MODULES; do
    local roots="1_install.sh 1_install"
    IFS=' '
    for root in $roots; do
      if [ -e modules/$module_path/$root ]; then
        tmp="$tmp `find modules/$module_path/$root -type f -print0  | sort -z | xargs -0 sha1sum`"
      fi
    done
  done

  local INSTALL_HASH=`echo "$tmp" | sha1sum`
  INSTALL_HASH="${INSTALL_HASH::${#INSTALL_HASH}-2}"

  getImageName $INSTALL_HASH; local image_id=$outp

  if [ -n "$image_id" ]; then
    echo "/!\ NOTE: Creating from a snapshot image is currently disabled due to issues 'Could not open /dev/net/tun: No such device' always creating from scratch"
    image_id=""
  fi

  if [ ! -z $CREATE_SNAPSHOT ]; then
    # Let's create a snapshot
    if [ -n "$image_id" ]; then
      echo "You already have a snapshot image of this install ($image_id)"
      exit -1
    else
      echo "================ SNAPSHOT ================"
      NODE_PREFIX="snapshot-image"
      createNodes 1 1
      registerDNS $NEW_SERVERS
      waitForServers $NEW_SERVERS

      checkForceInit; runInitPhase "$INIT_MODULES"
      runModulesInstall "$INIT_MODULES"
      
      # Get the server id and create a snapshot
      local server_id
      getServerId $NEW_SERVERS; server_id=$outp
      createSnapshot $INSTALL_HASH $server_id

      # Tear down
      echo "Tearing down snapshot node '$NODE_PREFIX'"
      getListOfServerNodes $NODE_PREFIX; nodes=$outp
      echo "y" | destroyNodes $nodes

      getListOfDNSEntries $NODE_PREFIX; nodes=$outp
      echo "y" | deregisterDNS $nodes

      echo "Now just rerun your cmd without --create-snapshot"
      exit 0
    fi
  elif [ -n "$image_id" ]; then
    # 1.1 If snapshot exists
    echo "Using snapshot ($image_id) to create nodes"
    SERVER_OS=$image_id

    if [ -z $REBUILD ]; then
      createNodes
      echo "Created $NEW_SERVERS"
      registerDNS "$NEW_SERVERS"
    else
      rebuildNodes
      echo "Rebuilt $NEW_SERVERS"
    fi
    
    if [ ! -z "$NEW_SERVERS" ] || [ ! -z "$EXISTING_SERVERS" ]; then
      waitForServers $NEW_SERVERS
    fi

    checkForceInit; runInitPhase "$INIT_MODULES"
  else
    # 1.2 else run all install steps:

    # Create all nodes manually 
    echo "Creating nodes from os image"
    if [ -z $REBUILD ]; then
      createNodes
      echo "Created $NEW_SERVERS"
      registerDNS "$NEW_SERVERS"
    else
      rebuildNodes
      echo "Rebuilt $NEW_SERVERS"
    fi

    if [ ! -z "$NEW_SERVERS" ] || [ ! -z "$EXISTING_SERVERS" ]; then
      waitForServers $NEW_SERVERS
    fi

    checkForceInit; runInitPhase "$INIT_MODULES"

    runModulesInstall "$INIT_MODULES"
  fi

  # 2. then run all configuration steps for one module at the time
  checkForceInit; runModulesConfigure "$INIT_MODULES"
  echo ""
}

createSnapshot() {
    local INSTALL_HASH="$1"
    local server_id="$2"

    # Create image from newly created server
    printf "Creating image of server $server_id and it will take 5 mins from `date`... "
    getServerId; local server_id=$outp
    local tmp=`hcloud server create-image --description "$NODE_TYPE ($SERVER_OS) $INIT_MODULES" --type snapshot $server_id` &>/dev/null
    IFS=' ' read n1 image_id n2 n3 n4 _server_id <<< $tmp
    # Add hash as label to allow finding it
    hcloud image add-label $image_id hash=$INSTALL_HASH &>/dev/null
    echo "done! @ `date`"
}
