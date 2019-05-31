#!/bin/bash
## Load variables to use in this script
INIT_PHASE="99_teardown"
[ -f common/vars ] && source common/vars
source common/utils.sh

echoStep "Teardown..."
echo "Do something..."