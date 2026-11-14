output "control_plane_name" {
  description = "Proxmox name of the k3s control-plane VM."
  value       = proxmox_virtual_environment_vm.control_plane.name
}

output "control_plane_address" {
  description = "Static IPv4 address of the control plane, without the prefix length."
  value       = local.control_plane_ip
}

output "worker_names" {
  description = "Proxmox names of the k3s worker VMs, sorted by address."
  value       = [for address in sort(keys(local.workers)) : proxmox_virtual_environment_vm.worker[address].name]
}

output "worker_addresses" {
  description = "Static IPv4 addresses of the workers, without the prefix length, sorted by address."
  value       = [for address in sort(keys(local.workers)) : local.workers[address].ip]
}

output "api_url" {
  description = "k3s API URL."
  value       = "https://${local.control_plane_ip}:6443"
}
