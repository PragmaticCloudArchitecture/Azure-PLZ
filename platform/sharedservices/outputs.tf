# Stable re-exports consumed by tf-subscription-vending and tf-app-workload.
# Names here are the downstream contract — internal renames do not cascade to
# consumers as long as these wrappers are maintained.

output "keyvault_id" {
  description = "Resource ID of the shared Key Vault. Consumed by tf-app-workload for Key Vault reference policies and tf-subscription-vending for RBAC role assignments."
  value       = module.keyvault.resource_id
}

output "keyvault_uri" {
  description = "Vault URI (https://<name>.vault.azure.net/). Used by application code and managed identity token requests."
  value       = module.keyvault.resource.vault_uri
}

output "keyvault_name" {
  description = "Name of the shared Key Vault."
  value       = module.keyvault.resource.name
}

output "private_endpoint_id" {
  description = "Resource ID of the Key Vault private endpoint, or null when no private endpoint was created."
  value       = try(module.keyvault.private_endpoints["vault"].resource.id, null)
}

output "resource_group_id" {
  description = "Resource ID of the shared services resource group."
  value       = azurerm_resource_group.sharedservices.id
}

output "resource_group_name" {
  description = "Name of the shared services resource group."
  value       = azurerm_resource_group.sharedservices.name
}
