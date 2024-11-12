#!/usr/bin/env bash

set -euo pipefail

CONTROL_PLANE_NODE_IP=$(sudo virsh net-dhcp-leases k8s_net | tail -n +3 | awk '{print $5, $6}' | grep cp01 | awk '{ print $1 }' | cut -d"/" -f1)

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm upgrade --install \
    cilium \
    cilium/cilium \
    --version 1.16.3 \
    --namespace kube-system \
    --set kubeProxyReplacement=true \
    --set envoy.enabled=false \
    --set k8sServiceHost="$CONTROL_PLANE_NODE_IP" \
    --set k8sServicePort="6443"
