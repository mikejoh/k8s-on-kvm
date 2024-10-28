# Kubernetes on KVM

## Pre-requisites

* KVM
* OpenTofu (the `terraform` fork)

## Notes

* See the `scripts/` folder for various utility scripts.
* You probably want to change `user` and `group` to `libvirt-qemu` and `kvm` respectively in `/etc/libvirt/qemu.conf` to mitigate permission issues on storage pools.

## Getting started

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

If you have problems with DHCP on the `k8s_net` and you're running `ufw` locally you might want to try the following:

```bash
sudo ufw allow in on virbr1 to any port 67 proto udp
sudo ufw allow out on virbr1 to any port 68 proto udp

sudo ufw reload
```

Remember that more `ufw` tweaking might be needed since it'll probably block traffic passing the bridge interface (created via the libvirt provider).

### Bootstrap the first control-plane node

```bash
sudo kubeadm init --control-plane-endpoint "LOAD_BALANCER_DNS:LOAD_BALANCER_PORT" --upload-certs
```

Replace `LOAD_BALANCER_DNS:LOAD_BALANCER_PORT` with e.g. `<IP of your VM>:6443`

### Create a multi-node control plane (for high availability)

Add control-plane nodes to the cluster:

```bash
echo "$(kubeadm token create --print-join-command) --control-plane --certificate-key $(kubeadm init phase upload-certs --upload-certs --skip-headers --skip-log-headers 2>/dev/null | tail -n 1)"
```

Add worker nodes to the cluster:

1. Generate the join command on a control-plane node:

```bash
kubeadm token create --print-join-command
```

2. Use the generate join command and run that on the worker node.

### Install a CNI plugin

Flannel CNI:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Calico CNI:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
```

Cilium CNI:

```bash
snap install helm --classic
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.16.3 --namespace kube-system
```

### Clean up the cluster

Run the clean-up utility script: `scripts/clean_up.sh`, please note that this removes everything related to the VMs and `tofu` state.
