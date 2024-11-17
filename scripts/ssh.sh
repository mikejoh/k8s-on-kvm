#!/usr/bin/env bash

PRIVATE_SSH_KEY="${PRIVATE_SSH_KEY:-$HOME/.ssh/id_rsa}"

LEASE_INFO=$(sudo virsh net-dhcp-leases k8s_net | tail -n +3 | awk '{print $5, $6}')

if [[ -z $LEASE_INFO ]]; then
    echo "No DHCP leases found for network 'k8s_net'."
    return
fi

SELECTED=$(echo "$LEASE_INFO" | awk '{print $2}' | fzf --prompt="Select hostname: ")

if [[ -n $SELECTED ]]; then
    IP=$(echo "$LEASE_INFO" | grep "$SELECTED" | awk '{print $1}' | cut -d'/' -f1)
    echo "Connecting to $SELECTED ($IP).."
    ssh "cloud@$IP" -i "$PRIVATE_SSH_KEY"
else
    echo "No selection made."
fi
