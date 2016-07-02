#!/bin/bash
set -e -x

cd $(dirname $0)

## Pre-requisites:
## - installed packages: apg, jq
## - installed azure cli
## - azure cli is in arm mode
## - you are logged in with azure cli

. ./common.sh

VM_NAME=vm-$(apg -a 1 -n 1 -m 7 -x 7 -M NL)
VM_HOST=${VM_NAME}.westus.cloudapp.azure.com

azure vm create -g ros-build2 \
    -o rancheros \
    -Q ${VM_IMAGE} \
    -n ${VM_NAME} \
    -i ${VM_NAME}-ip \
    -w ${VM_NAME} \
    -f ${VM_NAME}-nic \
    -F ${VM_NAME}-vnet -P ${VNET_PREFIX} -j sub1 -k ${VNET_SUBNET} \
    -z Standard_D2 -l westus -y Linux \
    -M ${USER_PUB} \
    -u rancher -p ${USER_PASS}

until ssh -F ./ssh_config -i ${USER_KEY} rancher@${VM_HOST} /bin/true; do
  sleep 2
done
