#!/usr/bin/env bash

set -euo pipefail

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm upgrade --install \
    cilium \
    cilium/cilium \
    --version 1.16.3 \
    --namespace kube-system \
    --set envoy.enabled=false \
    --set kubeProxyReplacement=true \
    --set routingMode=native \
    --set ipam.mode=kubernetes \
    --set autoDirectNodeRoutes=true \
    --set l2announcements.enabled=true \
    --set ipv4NativeRoutingCIDR="192.168.10.0/24" \
    --set k8sServiceHost="192.168.10.247" \
    --set k8sServicePort="6443"


