#!/bin/bash

# Remove all VMs and their storage
for dom in $(virsh list --all --name)
do
    virsh undefine $dom --remove-all-storage
done