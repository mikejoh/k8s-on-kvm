#!/usr/bin/env bash

set -euo pipefail

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm upgrade --install \
    cilium \
    cilium/cilium \
    --version 1.16.3 \
    --namespace kube-system
    --set envoy.enabled=false \
    --set ipam.mode=kubernetes \
    --set k8sServiceHost="192.168.10.108" \
    --set k8sServicePort="6443"
