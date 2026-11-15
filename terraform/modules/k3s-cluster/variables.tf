variable "name_prefix" {
  description = "Prefix for VM and snippet names. The dev stack uses trakr-dev."
  type        = string
}

variable "proxmox_node_name" {
  description = "Proxmox node that hosts the image, snippets, and VMs."
  type        = string
}

variable "datastore_id" {
  description = "Datastore for VM disks and the cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "image_datastore_id" {
  description = "Datastore that accepts Import content, used for the Ubuntu cloud image."
  type        = string
  default     = "local"
}

variable "snippet_datastore_id" {
  description = "Datastore that accepts Snippets content, used for cloud-init user data."
  type        = string
  default     = "local"
}

variable "bridge" {
  description = "Linux bridge attached to each VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "IPv4 gateway for the cluster network."
  type        = string

  validation {
    condition     = can(cidrhost("${var.gateway}/32", 0))
    error_message = "gateway must be an IPv4 address."
  }
}

variable "dns_servers" {
  description = "DNS servers passed to cloud-init."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "control_plane_address" {
  description = "Static IPv4 CIDR for the control plane, for example 192.168.1.40/24."
  type        = string

  validation {
    condition     = can(cidrhost(var.control_plane_address, 0))
    error_message = "control_plane_address must be an IPv4 CIDR."
  }
}

variable "worker_addresses" {
  description = "Static IPv4 CIDRs for the worker nodes. An empty list provisions only the control plane."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for address in var.worker_addresses : can(cidrhost(address, 0))
    ])
    error_message = "worker_addresses must contain only IPv4 CIDRs."
  }

  validation {
    condition = length(distinct([
      for address in var.worker_addresses : split("/", address)[0]
    ])) == length(var.worker_addresses)
    error_message = "worker_addresses must use a unique IPv4 address for each worker."
  }

  validation {
    condition = !contains([
      for address in var.worker_addresses : split("/", address)[0]
    ], split("/", var.control_plane_address)[0])
    error_message = "worker_addresses must not include the control-plane address."
  }
}

variable "ssh_public_key" {
  description = "SSH public key installed for the ubuntu user."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key."
  }
}

variable "k3s_version" {
  description = "k3s release installed on every node."
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "control_plane_cpu_cores" {
  description = "vCPU cores for the control plane."
  type        = number
  default     = 2
}

variable "control_plane_memory_mb" {
  description = "Memory in MiB for the control plane."
  type        = number
  default     = 4096
}

variable "control_plane_disk_gb" {
  description = "Boot disk size in GiB for the control plane. The template disk is the smaller of this value and worker_disk_gb."
  type        = number
  default     = 32

  validation {
    condition     = var.control_plane_disk_gb >= 8 && var.control_plane_disk_gb == floor(var.control_plane_disk_gb)
    error_message = "control_plane_disk_gb must be a whole number of at least 8 GiB."
  }
}

variable "data_disk_gb" {
  description = "Secondary virtio disk in GiB for Kubernetes persistent storage on the control plane. Set to 0 to omit it. Uses datastore_id."
  type        = number
  default     = 0

  validation {
    condition     = var.data_disk_gb >= 0 && var.data_disk_gb == floor(var.data_disk_gb)
    error_message = "data_disk_gb must be a whole number of GiB. Use 0 to omit the disk."
  }
}

variable "data_disk_interface" {
  description = "Proxmox interface for the secondary disk. virtio0 is the boot disk."
  type        = string
  default     = "virtio1"

  validation {
    condition     = can(regex("^virtio([1-9]|1[0-5])$", var.data_disk_interface))
    error_message = "data_disk_interface must be virtio1 through virtio15."
  }
}

variable "data_volume_group" {
  description = "LVM volume group created on a blank secondary disk. Also used as the virtio serial, so the guest finds the disk at /dev/disk/by-id/virtio-<name>."
  type        = string
  default     = "openebs-vg"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,19}$", var.data_volume_group))
    error_message = "data_volume_group must be 1-20 letters, digits, or . _ - and must start with a letter or digit so it is a valid virtio serial."
  }
}

variable "worker_cpu_cores" {
  description = "vCPU cores for each worker."
  type        = number
  default     = 2
}

variable "worker_memory_mb" {
  description = "Memory in MiB for each worker."
  type        = number
  default     = 4096
}

variable "worker_disk_gb" {
  description = "Boot disk size in GiB for each worker."
  type        = number
  default     = 40

  validation {
    condition     = var.worker_disk_gb >= 8 && var.worker_disk_gb == floor(var.worker_disk_gb)
    error_message = "worker_disk_gb must be a whole number of at least 8 GiB."
  }
}

variable "tags" {
  description = "Proxmox tags applied to the VMs."
  type        = list(string)
  default     = ["trakr", "k3s"]
}
