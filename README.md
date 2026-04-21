# Kubernetes on KVM

Deploy (small) Kubernetes clusters on KVM, all from scratch! 🚀

## ✅ Pre-requisites

* KVM (see your favourite Linux distribution how-to)
* OpenTofu (the `terraform` fork)

## 🗒️ Important notes

* See the `scripts/` folder for various utility scripts.
* You probably want to change `user` and `group` to `libvirt-qemu` and `kvm` respectively in `/etc/libvirt/qemu.conf` to mitigate permission issues on storage pools.
* All cluster nodes will be running Ubuntu 24.04.

## 🏃 Getting started

### Firewall rules (only if `ufw` is active on the host)

Skip this section if you don't run `ufw`. If you do, don't disable it — add narrowly-scoped rules instead. The cluster VMs sit behind a libvirt NAT network and rely on the host to forward their traffic to the internet; during provisioning, cloud-init downloads apt packages, Kubernetes repos, container images, Falco, etc. `ufw`'s default-drop `FORWARD` policy will silently kill those packets and bootstrap will hang partway through.

The VM subnet is deterministic — whatever you set as `k8s_network_cidr` in `k8s.auto.tfvars`. Scope rules to that CIDR rather than to the bridge interface (libvirt picks `virbr0`, `virbr1`, ... based on creation order, and the name can drift if you recreate networks).

```bash
# Replace 192.168.10.0/24 with your k8s_network_cidr.

# Allow forwarded traffic from the cluster network to anywhere (internet access)
sudo ufw route allow from 192.168.10.0/24

# Allow the VMs to reach libvirt's dnsmasq on the host for DHCP and DNS
sudo ufw allow in on virbr1 to any port 67 proto udp
sudo ufw allow in on virbr1 to any port 53
```

If you don't know which bridge libvirt assigned to `k8s_net`, check with `virsh net-dumpxml k8s_net | grep bridge`.

Verify from a node once the VMs are up (cloud-init will have already exercised this if it succeeded):

```bash
ssh cloud@<node-ip> 'curl -sI https://pkgs.k8s.io | head -1'
```

### Set up libvirt for rootless access

The scripts in this repo assume you can talk to the system libvirt daemon without `sudo`. Three things need to be true:

1. **Your user is in the `libvirt` group.** Add yourself if not:

    ```bash
    sudo usermod -aG libvirt "$USER"
    ```

    Log out and back in (or `newgrp libvirt`) so the group is active in your shell.

2. **The system libvirt daemon is running.** Recent libvirt (default in Arch, Fedora, RHEL 9+) splits the old monolithic `libvirtd` into one socket-activated daemon per subsystem — `virtqemud` handles VM domains, `virtnetworkd` virtual networks, `virtstoraged` storage pools, `virtnwfilterd` packet filters, `virtsecretd` secrets. Enable their sockets so each starts on demand:

    ```bash
    sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket virtnwfilterd.socket virtsecretd.socket
    ```

    On distros that still ship the monolithic daemon (e.g. Debian, Ubuntu), `sudo systemctl enable --now libvirtd.socket` replaces all of the above.

3. **`virsh` defaults to `qemu:///system`.** Without configuration, bare `virsh` connects to `qemu:///session` — a separate per-user daemon that does *not* see the VMs this repo creates. Point libvirt clients at the system daemon:

    ```bash
    mkdir -p ~/.config/libvirt
    echo 'uri_default = "qemu:///system"' >> ~/.config/libvirt/libvirt.conf
    ```

Verify the wiring before provisioning:

```bash
virsh uri          # should print qemu:///system
virsh list --all   # should return without permission errors
```

### Provision cluster nodes

By default we'll deploy a cluster on three nodes, they will have both the control-plane and worker roles.

_If you're setting a lower resource values on each node then you might need to set: `--ignore-preflight-errors=mem,numcpu` during `kubeadm init`._

1. Generate an SSH keypair that cloud-init will embed into the `cloud` user on each node (skip if you already have one you want to reuse):

    ```bash
    ssh-keygen -t ed25519 -f ~/.ssh/kvm-k8s -N ''
    ```

2. Change the `k8s.auto.tfvars` to fit your needs:

    - `ssh_public_key_path` — path to the `.pub` from step 1 (or any existing public key you want authorised on the nodes).
    - `pool_path` — an existing directory on your host that qemu (typically running as `libvirt-qemu:kvm`) can read and write. A common choice is a dedicated directory under `/var/lib/libvirt/` (the default libvirt storage area), shared with any other VMs you run locally.
    - `k8s_network_cidr`, `cluster_name`, `kubernetes_minor_version`, and the `k8s_nodes` list — tune to match the cluster you want.

3. Run `tofu init`
4. Run `tofu plan`
5. Run `tofu apply`
6. The needed nodes shall be provisioned with everything included for you to start bootstrapping the cluster.

### Accessing the nodes

_Remember to start your VMs after a reboot!_

#### SSH to one node a time

To find out the IP addresses of the VMs you can run the following using `virsh`:

```bash
virsh net-dhcp-leases k8s_net
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

virsh net-dhcp-leases k8s_net | tail -n +3 | awk '{print $5 }' | cut -d"/" -f1 | xpanes -l ev -c 'ssh -l cloud -i <PRIVATE_KEY> {}'
```

### Bootstrap the first control-plane node

_Please note that we're skipping the addon `kube-proxy` since in these clusters we want to utilize Cilium as the CNI and with a configuration that replaces the need for `kube-proxy`._

```bash
CONTROL_PLANE_IP=$(ip addr show ens3 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
sudo kubeadm init --control-plane-endpoint "$CONTROL_PLANE_IP:6443" --upload-certs
```

### Add a worker node

Add worker nodes to the cluster:

1. Generate the join command on a control-plane node:

```bash
kubeadm token create --print-join-command
```

2. Use the generate join command and run that on the worker node.

### Upgrade cluster

_As of writing this the clusters are deployed with the latest available patch release of `v1.30`. The following guide will upgrade the cluster to `v1.31.2`._

1. Add the following line to the `/etc/apt/sources.list.d/kubernetes.list`, note the Kubernetes version:

```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" >> /etc/apt/sources.list.d/kubernetes.list
```

2. Run `apt update`.

3. Check which install candidate we have: `apt policy kubeadm`

```bash
kubeadm:
  Installed: 1.30.6-1.1
  Candidate: 1.31.2-1.1
  Version table:
 *** 1.31.2-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.31/deb  Packages
     1.31.1-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.31/deb  Packages
     1.31.0-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.31/deb  Packages
     1.30.6-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.5-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.4-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.3-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.2-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.1-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
     1.30.0-1.1 500
        500 https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
```

4. Install a newer version `kubeadm`:

```bash
apt install kubeadm=1.31.2-1.1
```

5. Drain and cordon the control-plane node:

```bash
kubectl drain <node name> --ignore-daemonsets --delete-emptydir-data --disable-eviction
```

_Use `--disable-eviction` flag with caution, in this case we'll have a small test cluster which most likely wont accomodate for any Pod Distruption Budgets configured._

6. Check the upgrade `plan` and proceed with upgrade:

```bash
kubeadm upgrade plan
kubeadm upgrade apply v1.31.2
```

```bash
[upgrade/version] You have chosen to change the cluster version to "v1.31.2"
[upgrade/versions] Cluster version: v1.30.6
[upgrade/versions] kubeadm version: v1.31.2
[upgrade] Are you sure you want to proceed? [y/N]: y
```

7. Upgrade `kubelet` and `kubectl`:

```bash
apt install kubelet=1.31.2-1.1 kubectl=1.31.2-1.1
```

8. Continue with the rest of the control-plane nodes.

Check versions:

```bash
kubectl version
Client Version: v1.31.2
Kustomize Version: v5.4.2
Server Version: v1.31.2

kubectl get nodes
NAME         STATUS   ROLES           AGE     VERSION
k8s01-cp01   Ready    control-plane   4d21h   v1.31.2
k8s01-w01    Ready    <none>          4d20h   v1.30.6
```

_Please note that for workers you'll only install a newer version of the `kubelet`!_

### Clean up the cluster

Run `scripts/clean_up.sh` to tear down this cluster and reset tofu state. The script reads `cluster_name` from `k8s.auto.tfvars` and only touches domains whose name starts with that prefix, so unrelated VMs on the same libvirt host are left alone. It also destroys the `k8s_net` network and `k8s` pool (both created by this repo) and removes `terraform.tfstate*` files.

## 📚 Add-ons

### Install Cilium

```bash
./scripts/install_cilium.sh
```

_Note that we run Cilium with `kubeProxyReplacement=true` with `kube-proxy` running, you could remove all things related to `kube-proxy` [manually](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#quick-start) or skip the `kube-proxy` phase during `kubeadm init`._

### Install Open Policy Agent Gatekeeper

1. Install:

```bash
./scripts/install_opa.sh
```

2. Create a constraint template and a constraint:

```bash
kubectl create -f manifests/opa/image-constraint.yaml
```
