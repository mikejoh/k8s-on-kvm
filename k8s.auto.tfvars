kubernetes_version  = "1.29.1"
cluster_name        = "k8s01"
image_source        = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
pool_path           = ""
ssh_public_key_path = ""

k8s_nodes = [
  {
    name      = "cp01"
    vcpu      = 2
    memory    = 2048
    node_type = "control-plane"
  },
  {
    name      = "cp02"
    vcpu      = 2
    memory    = 2048
    node_type = "control-plane"
  },
  {
    name      = "cp03"
    vcpu      = 2
    memory    = 2048
    node_type = "control-plane"
  }
]
