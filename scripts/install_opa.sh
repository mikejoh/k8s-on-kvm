#!/usr/bin/env bash

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update gatekeeper
helm upgrade \
    --install \
    gatekeeper \
    gatekeeper/gatekeeper \
    --namespace gatekeeper-system \
    --version 3.17.1 \
    --create-namespace \
    --set replicas=1 \
    --set controllerManager.resources=null \
    --set audit.resources=null