#!/usr/bin/env bash

set -euo pipefail

# Tear down libvirt resources created by this repo: domains whose name starts
# with "<cluster_name>-" (read from k8s.auto.tfvars), the k8s_net network, the
# k8s pool, and the local tofu state files. Leaves unrelated VMs untouched.

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TFVARS="${REPO_ROOT}/k8s.auto.tfvars"

if [[ ! -f $TFVARS ]]; then
    echo "error: ${TFVARS} not found" >&2
    exit 1
fi

CLUSTER_NAME=$(awk -F'=' '
    /^[[:space:]]*cluster_name[[:space:]]*=/ {
        gsub(/["[:space:]]/, "", $2)
        print $2
        exit
    }' "$TFVARS")

if [[ -z ${CLUSTER_NAME:-} ]]; then
    echo "error: could not parse cluster_name from ${TFVARS}" >&2
    exit 1
fi

echo "Tearing down cluster: ${CLUSTER_NAME}"

for dom in $(virsh list --all --name | grep -- "^${CLUSTER_NAME}-" || true); do
    state=$(virsh domstate "$dom" 2>/dev/null || echo unknown)
    if [[ $state != "shut off" ]]; then
        echo "Shutting down $dom (state=$state)..."
        virsh shutdown "$dom" 2>/dev/null || virsh destroy "$dom" || true
        while [[ $(virsh domstate "$dom" 2>/dev/null) != "shut off" ]]; do
            echo "Waiting for $dom to stop..."
            sleep 1
        done
    fi

    echo "Undefining $dom and removing storage..."
    virsh undefine "$dom" --remove-all-storage
done

rm -rf "${REPO_ROOT}"/terraform.tfstate*

virsh net-destroy k8s_net 2>/dev/null || true
virsh net-undefine k8s_net 2>/dev/null || true
virsh pool-destroy k8s 2>/dev/null || true
virsh pool-undefine k8s 2>/dev/null || true
