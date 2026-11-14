variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://proxmox.example.com:8006/. The API token is read from PROXMOX_VE_API_TOKEN."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API endpoint."
  type        = bool
  default     = true
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
}

variable "dns_servers" {
  description = "DNS servers passed to cloud-init."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "control_plane_address" {
  description = "Static IPv4 CIDR for the control plane, for example 192.168.1.40/24."
  type        = string
}

variable "worker_addresses" {
  description = "Static IPv4 CIDRs for the worker nodes. An empty list provisions only the control plane."
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "SSH public key installed for the ubuntu user on every node."
  type        = string
}
