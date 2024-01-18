#!/bin/bash

# Remove all resources created with terraform

for dom in $(virsh list --all --name)
do
    virsh undefine $dom --remove-all-storage
done

virsh net-undefine k8s_net
virsh pool-undefine k8s