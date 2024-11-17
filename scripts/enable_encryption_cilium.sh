#!/usr/bin/env bash

set -euo pipefail

helm upgrade --install \
    cilium \
    cilium/cilium \
    --reuse-values \
    --version 1.16.3 \
    --namespace kube-system \
    --set encryption.enabled=true \
    --set encryption.type=wireguard

