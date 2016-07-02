#!/bin/bash
set -e -x

cd $(dirname $0)

## Pre-requisites:
## - installed packages: apg, jq
## - installed azure cli
## - azure cli is in arm mode
## - you are logged in with azure cli

. ./common.sh

VM_DISK="https://rancheroso3.blob.core.windows.net/vhds/build-ll2ftc6-20160701-153649462.vhd"
VM_NAME=vm-$(apg -a 1 -n 1 -m 7 -x 7 -M NL)
VM_HOST=${VM_NAME}.westus.cloudapp.azure.com

azure vm create -g ros-build \
    -o rancheroso3 \
    -Q ${VM_DISK} \
    -n ${VM_NAME} \
    -i ${VM_NAME}-ip \
    -w ${VM_NAME} \
    -f ${VM_NAME}-nic \
    -F ${VM_NAME}-vnet -P ${VNET_PREFIX} -j sub1 -k ${VNET_SUBNET} \
    -z Standard_DS2_v2 -l westus -y Linux \
    -M ${USER_PUB} \
    -u rancher -p ${USER_PASS} \
    --custom-data cloud-config.yml

echo ssh -F ./ssh_config_term -i ${USER_KEY} rancher@${VM_HOST}

#until ssh -F ./ssh_config -i ${USER_KEY} rancher@${VM_HOST} /bin/true; do
#  sleep 2
#done
