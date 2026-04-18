# Stable output wrappers around module outputs.
# Naming these at the root level insulates consumers from internal AVM renames.

output "management_group_resource_ids" {
  description = "Map of management group names to their fully-qualified Azure resource IDs. Consumed by tf-platform-connectivity to position hub VNets and by tf-subscription-vending for subscription placement."
  value       = module.alz.management_group_resource_ids
}

output "policy_definition_resource_ids" {
  description = "Map of custom policy definition names to their resource IDs."
  value       = module.alz.policy_definition_resource_ids
}

output "policy_set_definition_resource_ids" {
  description = "Map of custom policy set (initiative) definition names to their resource IDs."
  value       = module.alz.policy_set_definition_resource_ids
}

output "policy_assignment_resource_ids" {
  description = "Map of policy assignment names (keyed as '<management_group_id>/<assignment_name>') to their resource IDs."
  value       = module.alz.policy_assignment_resource_ids
}

output "policy_assignment_identity_ids" {
  description = "Map of policy assignment names to the principal IDs of their managed identities. Feed these into tf-platform-connectivity and tf-platform-monitoring to grant role assignments on target resources such as private DNS zones and DCRs."
  value       = module.alz.policy_assignment_identity_ids
}

output "policy_role_assignment_resource_ids" {
  description = "Map of policy role assignment names to their resource IDs."
  value       = module.alz.policy_role_assignment_resource_ids
}

output "role_definition_resource_ids" {
  description = "Map of custom role definition names to their resource IDs."
  value       = module.alz.role_definition_resource_ids
}
