locals {
  control_plane_ip   = split("/", var.control_plane_address)[0]
  control_plane_name = "${var.name_prefix}-k3s-cp"
  ssh_public_key     = trimspace(var.ssh_public_key)

  workers = {
    for address in var.worker_addresses :
    address => {
      address = address
      ip      = split("/", address)[0]
      name    = "${var.name_prefix}-k3s-worker-${replace(split("/", address)[0], ".", "-")}"
    }
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "proxmox_download_file" "ubuntu" {
  content_type = "import"
  datastore_id = var.image_datastore_id
  node_name    = var.proxmox_node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "template" {
  name        = "${var.name_prefix}-k3s-template"
  description = "Ubuntu 24.04 template for the TrakR k3s cluster. Managed by Terraform."
  tags        = var.tags
  node_name   = var.proxmox_node_name

  template = true
  started  = false
  on_boot  = false

  agent {
    enabled = false
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.control_plane_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.control_plane_memory_mb
    floating  = var.control_plane_memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = proxmox_download_file.ubuntu.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.control_plane_disk_gb
  }

  network_device {
    bridge = var.bridge
  }

  serial_device {}
}

resource "proxmox_virtual_environment_file" "control_plane_user_data" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "${local.control_plane_name}-user-data.yaml"
    data = templatefile("${path.module}/templates/control-plane.yaml.tftpl", {
      hostname       = local.control_plane_name
      ssh_public_key = local.ssh_public_key
      k3s_version    = var.k3s_version
      token          = random_password.k3s_token.result
      node_ip        = local.control_plane_ip
    })
  }
}

resource "proxmox_virtual_environment_vm" "control_plane" {
  name        = local.control_plane_name
  description = "TrakR k3s control plane. Managed by Terraform."
  tags        = var.tags
  node_name   = var.proxmox_node_name

  started         = true
  stop_on_destroy = true

  clone {
    vm_id   = proxmox_virtual_environment_vm.template.id
    retries = 3
  }

  startup {
    order    = "1"
    up_delay = "30"
  }

  agent {
    enabled = true
    timeout = "15m"

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = var.control_plane_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.control_plane_memory_mb
    floating  = var.control_plane_memory_mb
  }

  initialization {
    datastore_id = var.datastore_id
    upgrade      = false

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.control_plane_address
        gateway = var.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.control_plane_user_data.id
  }

  network_device {
    bridge = var.bridge
  }
}

resource "proxmox_virtual_environment_file" "worker_user_data" {
  for_each = local.workers

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "${each.value.name}-user-data.yaml"
    data = templatefile("${path.module}/templates/worker.yaml.tftpl", {
      hostname       = each.value.name
      ssh_public_key = local.ssh_public_key
      k3s_version    = var.k3s_version
      token          = random_password.k3s_token.result
      server_ip      = local.control_plane_ip
    })
  }
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = local.workers

  name        = each.value.name
  description = "TrakR k3s worker. Managed by Terraform."
  tags        = var.tags
  node_name   = var.proxmox_node_name

  started         = true
  stop_on_destroy = true

  clone {
    vm_id   = proxmox_virtual_environment_vm.template.id
    retries = 3
  }

  startup {
    order = "2"
  }

  agent {
    enabled = true
    timeout = "15m"

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = var.worker_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory_mb
    floating  = var.worker_memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.worker_disk_gb
  }

  initialization {
    datastore_id = var.datastore_id
    upgrade      = false

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = each.value.address
        gateway = var.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_user_data[each.key].id
  }

  network_device {
    bridge = var.bridge
  }

  depends_on = [proxmox_virtual_environment_vm.control_plane]
}
