output "subscription_id" {
  description = "The GUID of the vended Azure subscription."
  value       = module.vending.subscription_id
}

output "subscription_resource_id" {
  description = "The Azure resource ID of the vended subscription."
  value       = "/subscriptions/${module.vending.subscription_id}"
}

output "virtual_network_id" {
  description = "The resource ID of the vended spoke VNet, or null if no VNet was created."
  value       = try(module.vending.virtual_networks["default"].id, null)
}

output "workload_identity_id" {
  description = "The resource ID of the workload UAMI, or null if not created."
  value       = try(module.vending.user_managed_identities["default"].id, null)
}

output "workload_identity_client_id" {
  description = "The client (application) ID of the workload UAMI, or null if not created."
  value       = try(module.vending.user_managed_identities["default"].client_id, null)
}

output "workload_identity_principal_id" {
  description = "The principal (object) ID of the workload UAMI, or null if not created."
  value       = try(module.vending.user_managed_identities["default"].principal_id, null)
}

output "entra_group_object_id" {
  description = "The object ID of the Entra ID workload team group, or null if not created."
  value       = try(azuread_group.workload_team[0].object_id, null)
}
