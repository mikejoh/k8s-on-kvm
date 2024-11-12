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
5. The needed nodes shall be provisioned with everything included for you to start bootstrapping the cluster.

### Accessing the nodes

#### SSH to one node a time

To find out the IP addresses of the VMs you can run the following using `virsh`:

```bash
sudo virsh net-dhcp-leases k8s_net
```

#### SSH using the provided helper script

This requires that you have [`fzf`](https://github.com/junegunn/fzf) installed.

```bash
PRIVATE_SSH_KEY=~/.ssh/kvm-k8s scripts/ssh.sh
```

_Make sure you're using the private key that matches the public key added as part of the cluster node provisioning. We're adding a user called `cloud` by default that has the provided public key as one of the `ssh_authorized_keys`._

#### Using `tmux` and `xpanes` to SSH to all available nodes

Don't forget to inline the private key path below and replace `<PRIVATE_KEY>` before running the command:

```bash
tmux

sudo virsh net-dhcp-leases k8s_net | tail -n +3 | awk '{print $5 }' | cut -d"/" -f1 | xpanes -l ev -c 'ssh -l cloud -i <PRIVATE_KEY> {}'
```

### Bootstrap the first control-plane node

_Please note that we're skipping the addon `kube-proxy` since in these clusters we want to utilize Cilium as the CNI and with a configuration that replaces the need for `kube-proxy`._

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
./scripts/install_cilium.sh
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
