output "name_prefix" {
  description = "Prefix applied to resource names in this environment."
  value       = module.stack.name_prefix
}

output "tags" {
  description = "Tags applied to resources in this environment."
  value       = module.stack.tags
}
