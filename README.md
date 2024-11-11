# Kubernetes on KVM

Deploy (small) Kubernetes clusters on KVM, all from scratch! 🚀

## Pre-requisites ✅

* KVM (see your favourite Linux distribution how-to)
* OpenTofu (the `terraform` fork)

## Important notes 🗒️

* See the `scripts/` folder for various utility scripts.
* You probably want to change `user` and `group` to `libvirt-qemu` and `kvm` respectively in `/etc/libvirt/qemu.conf` to mitigate permission issues on storage pools.
* The VMs will be running a Ubuntu 24.04 image (latest)
* You'll get `containerd` _and_ CRI-O as runtimes, if you want to test something related to e.g. `RuntimeClass`

## Getting started 🏃

### Provision cluster nodes

By default we'll deploy a cluster on three nodes, they will have both the control-plane and worker roles.

_If you're setting a lower resource values on each node then you might need to set: `--ignore-preflight-errors=mem,numcpu` during `kubeadm init`._

1. Change the `k8s.auto.tfvars` to fit your needs!
2. Run `tofu init`
3. Run `tofu plan`
4. Run `tofu apply`
5. SSH to all nodes using the private and public key pair you referenced when deploying the cluster. You can find the IP addresses of the cluster nodes by running:

```bash
sudo virsh net-dhcp-leases k8s_net
```

Proceed with the bootstrapping the Kubernetes cluster using e.g. `kubeadm`.

Remember that more `ufw` tweaking might be needed since it'll probably block traffic passing the bridge interface (created via the libvirt provider).

### Bootstrap the first control-plane node

```bash
CONTROL_PLANE_IP=$(ip addr show ens3 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
sudo kubeadm init --skip-phases=addon/kube-proxy --control-plane-endpoint "$CONTROL_PLANE_IP:6443" --upload-certs
```

### Add a worker node

Add worker nodes to the cluster:

1. Generate the join command on a control-plane node:

```bash
kubeadm token create --print-join-command
```

2. Use the generate join command and run that on the worker node.

### Install Cilium

```bash
helm upgrade --install \
    cilium \
    cilium/cilium \
    --version 1.16.3 \
    --namespace kube-system \
    --set externalIPs.enabled=true \
    --set l2announcements.enabled=true \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="192.168.10.247" \
    --set k8sServicePort="6443" \
    --set envoy.enabled=false
```

## Add-ons

### Install Open Policy Agent Gatekeeper

1. Install:

```bash
helm upgrade \
    --install \
    gatekeeper \
    gatekeeper/gatekeeper \
    --namespace gatekeeper-system \
    --create-namespace \
    --set replicas=1 \
    --set controllerManager.resources=null \
    --set audit.resources=null
```

2. Add a constraint template.

### Clean up the cluster

Run the clean-up utility script: `scripts/clean_up.sh`, please note that this removes everything related to the VMs and `tofu` state.
