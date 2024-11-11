variable "kubernetes_minor_version" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "k8s_nodes" {
  type = set(object({
    name      = string
    vcpu      = number
    memory    = number
    node_type = string
  }))
}

variable "image_source" {
  type = string
}

variable "pool_path" {
  type = string
}
