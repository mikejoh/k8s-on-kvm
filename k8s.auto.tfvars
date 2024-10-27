kubernetes_version  = "1.31.2"
cluster_name        = "k8s01"
image_source        = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
pool_path           = "/home/mikael/k8s-pool/"
ssh_public_key_path = "~/.ssh/kvm-k8s.pub"

k8s_nodes = [
  {
    name      = "cp01"
    vcpu      = 2
    memory    = 2048
    node_type = "control-plane"
  },
  {
    name      = "w01"
    vcpu      = 1
    memory    = 1048
    node_type = "worker"
  }
]
