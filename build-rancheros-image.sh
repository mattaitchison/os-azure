#!/bin/bash
set -e -x

cd $(dirname $0)

## Pre-requisites:
## - installed packages: apg, jq
## - installed azure cli
## - azure cli is in arm mode
## - you are logged in with azure cli

. ./common.sh
VM_RESOURCE_NAME="ros-build-r"
VM_NAME=build-$(apg -a 1 -n 1 -m 7 -x 7 -M NL)
VM_HOST=${VM_RESOURCE_NAME}.westus.cloudapp.azure.com
VM_USER="core"

azure vm create -g ros-build \
    -o rancheroso3 \
    -Q ${VM_IMAGE} \
    -n ${VM_NAME} \
    -i ${VM_RESOURCE_NAME}-ip \
    -w ${VM_NAME} \
    -f ${VM_RESOURCE_NAME}-nic \
    -F ${VM_RESOURCE_NAME}-vnet -P ${VNET_PREFIX} -j sub1 -k ${VNET_SUBNET} \
    -z Standard_DS2_v2 -l westus -y Linux \
    -M ${USER_PUB} \
    -u ${VM_USER} -p ${USER_PASS}
azure vm disk attach-new -g ros-build -o rancheroso3 -n ${VM_NAME} 2

until ssh -F ./ssh_config -i ${USER_KEY} ${VM_USER}@${VM_HOST} /bin/true; do
  sleep 2
done

sftp -F ./ssh_config -i ${USER_KEY} ${VM_USER}@${VM_HOST}:/home/${VM_USER} <<EOF
put azure.yml
EOF

ssh -F ./ssh_config -i ${USER_KEY} ${VM_USER}@${VM_HOST} <<EOF
  docker pull mattaitchison/waagent
  docker tag mattaitchison/waagent waagent

  echo Saving docker images to: azure.tar.xz ...
  docker save waagent | xz > azure.tar.xz
  echo Done.

  docker run --privileged --net=host --entrypoint=/scripts/set-disk-partitions mattaitchison/os:${ROS_VERSION} /dev/sdc

  docker run --privileged --net=host -v=/home:/home \
    -e KERNEL_ARGS='earlyprintk=ttyS0 rootdelay=300 rancher.password=rancher rancher.modules=[isofs,ata_piix]' \
    mattaitchison/os:${ROS_VERSION} \
      -d /dev/sdc -t googlecompute -c /home/${VM_USER}/azure.yml \
      -f /home/${VM_USER}/azure.tar.xz:/var/lib/rancher/preload/system-docker/azure.tar.xz
EOF

mkdir -p ./tmp

azure vm disk list --json -g ros-build -n ${VM_NAME} > ./tmp/disks.json


#DISK_NAME=$(cat tmp/disks.json | jq '.[0].name' | xargs -I{} echo {})
IMAGE_VHD=$(cat tmp/disks.json | jq '.[0].vhd.uri' | xargs -I{} echo {})

azure vm disk detach -g ros-build -n ${VM_NAME} -l 0
echo "Sleeping for 60 seconds... (let azure finish with detaching the disk)"
sleep 60

#azure vm disk delete ${DISK_NAME}

azure vm deallocate -g ros-build -n ${VM_NAME}
azure vm delete -g ros-build -n ${VM_NAME} -q

echo ${IMAGE_VHD}
