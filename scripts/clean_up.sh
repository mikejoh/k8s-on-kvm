#!/usr/bin/env bash

set -euo pipefail

# Remove all resources created with todu
for dom in $(sudo virsh list --all --name); do
    echo "Shutting down $dom..."
    sudo virsh shutdown "$dom"

    # Wait for the VM to stop
    while [[ $(sudo virsh domstate "$dom") != "shut off" ]]; do
        echo "Waiting for $dom to stop..."
        sleep 1
    done

    # Undefine and remove storage once stopped
    echo "Undefining $dom and removing storage..."
    sudo virsh undefine "$dom" --remove-all-storage
done

sudo virsh net-undefine k8s_net
sudo virsh net-destroy k8s_net
sudo virsh pool-undefine k8s
sudo virsh pool-destroy k8s

rm -rf terraform.tfstate*
