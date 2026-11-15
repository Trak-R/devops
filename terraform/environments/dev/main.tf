module "stack" {
  source = "../../modules/stack"

  environment = "dev"
}

module "k3s" {
  source = "../../modules/k3s-cluster"

  name_prefix             = module.stack.name_prefix
  proxmox_node_name       = var.proxmox_node_name
  datastore_id            = var.datastore_id
  image_datastore_id      = var.image_datastore_id
  snippet_datastore_id    = var.snippet_datastore_id
  bridge                  = var.bridge
  gateway                 = var.gateway
  dns_servers             = var.dns_servers
  control_plane_address   = var.control_plane_address
  control_plane_cpu_cores = 4
  control_plane_memory_mb = 8192
  control_plane_disk_gb   = var.control_plane_disk_gb
  data_disk_gb            = var.data_disk_gb
  worker_addresses        = var.worker_addresses
  ssh_public_key          = var.ssh_public_key
  tags                    = ["trakr", "dev", "k3s"]
}
