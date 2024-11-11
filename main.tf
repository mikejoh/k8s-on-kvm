resource "libvirt_pool" "pool" {
  name = "k8s"
  type = "dir"
  target {
    path = var.pool_path
  }
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  for_each       = { for node in var.k8s_nodes : "${node.name}" => node }
  name           = "${var.cluster_name}-${each.value.name}-cloud-init.iso"
  user_data      = data.template_file.cloud_init[each.key].rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.pool.name
}

resource "libvirt_volume" "volume" {
  for_each = { for node in var.k8s_nodes : "${node.name}" => node }
  name     = "${var.cluster_name}-${each.value.name}-img-vol"
  pool     = libvirt_pool.pool.name
  source   = var.image_source
  format   = "qcow2"
}

resource "libvirt_volume" "resized_volume" {
  for_each       = { for node in var.k8s_nodes : "${node.name}" => node }
  name           = "${var.cluster_name}-${each.value.name}-vol"
  base_volume_id = libvirt_volume.volume[each.key].id
  pool           = libvirt_pool.pool.name
  size           = 10737418240
}

data "template_file" "cloud_init" {
  for_each = { for node in var.k8s_nodes : "${node.name}" => node }

  template = templatefile("${path.module}/cloud-init/cloud_init.cfg", {
    ssh_public_key           = file("${var.ssh_public_key_path}")
    hostname                 = "${var.cluster_name}-${each.value.name}"
    kubernetes_minor_version = "${var.kubernetes_minor_version}"
    node_type                = "${each.value.node_type}"
  })
}

data "template_file" "network_config" {
  template = file("${path.module}/cloud-init/network_config.cfg")
}

resource "libvirt_network" "network" {
  name      = "k8s_net"
  mode      = "nat"
  addresses = ["192.168.10.0/24"]
  autostart = true
  dhcp {
    enabled = true
  }
}

resource "libvirt_domain" "nodes" {
  for_each    = { for node in var.k8s_nodes : "${node.name}" => node }
  name        = "${var.cluster_name}-${each.value.name}"
  description = "Kubernetes ${each.value.node_type}"
  vcpu        = each.value.vcpu
  memory      = each.value.memory

  cloudinit = libvirt_cloudinit_disk.cloud_init[each.key].id

  disk {
    volume_id = libvirt_volume.resized_volume[each.key].id
  }

  network_interface {
    wait_for_lease = true
    network_id     = libvirt_network.network.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}
