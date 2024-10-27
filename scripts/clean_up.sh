#!/bin/bash

rm -rf terraform.tfstate*
rm -rf .terraform

# Remove all resources created with todu
for dom in $(virsh list --all --name)
do
    sudo virsh shutdown $dom
    sudo virsh undefine $dom --remove-all-storage
done

sudo virsh net-undefine k8s_net
sudo virsh net-destroy k8s_net
sudo virsh pool-undefine k8s
sudo virsh pool-destroy k8s

POOL_PATH=$(sudo virsh pool-dumpxml k8s | grep "<path>" | sed "s/.*<path>//;s/<\/path>.*//")
rm -rf $POOL_PATH