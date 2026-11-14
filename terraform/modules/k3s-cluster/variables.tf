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
  description = "Static IPv4 CIDRs for the two workers."
  type        = list(string)

  validation {
    condition     = length(var.worker_addresses) == 2 && alltrue([for address in var.worker_addresses : can(cidrhost(address, 0))])
    error_message = "worker_addresses must contain exactly two IPv4 CIDRs."
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
  description = "Disk size in GiB for the control plane and the template."
  type        = number
  default     = 32
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
  description = "Disk size in GiB for each worker."
  type        = number
  default     = 40
}

variable "tags" {
  description = "Proxmox tags applied to the VMs."
  type        = list(string)
  default     = ["trakr", "k3s"]
}
