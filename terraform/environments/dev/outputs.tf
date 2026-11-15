output "name_prefix" {
  description = "Prefix applied to resource names in this environment."
  value       = module.stack.name_prefix
}

output "tags" {
  description = "Tags applied to resources in this environment."
  value       = module.stack.tags
}

output "control_plane_name" {
  description = "Proxmox name of the k3s control-plane VM."
  value       = module.k3s.control_plane_name
}

output "control_plane_address" {
  description = "Static IPv4 address of the control plane."
  value       = module.k3s.control_plane_address
}

output "worker_names" {
  description = "Proxmox names of the k3s worker VMs."
  value       = module.k3s.worker_names
}

output "worker_addresses" {
  description = "Static IPv4 addresses of the workers."
  value       = module.k3s.worker_addresses
}

output "api_url" {
  description = "k3s API URL."
  value       = module.k3s.api_url
}

output "control_plane_disk_gb" {
  description = "Boot disk size in GiB for the control plane."
  value       = module.k3s.control_plane_disk_gb
}

output "data_disk_gb" {
  description = "Secondary disk size in GiB on the control plane. Zero means the disk is omitted."
  value       = module.k3s.data_disk_gb
}

output "data_volume_group" {
  description = "LVM volume group prepared on a blank secondary disk."
  value       = module.k3s.data_volume_group
}
