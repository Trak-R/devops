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
