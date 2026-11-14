output "name_prefix" {
  description = "Prefix for resource names in this environment."
  value       = local.name_prefix
}

output "tags" {
  description = "Tags for resources in this environment."
  value       = local.tags
}
