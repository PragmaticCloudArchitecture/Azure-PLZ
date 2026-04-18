output "management_group_resource_ids" {
  description = "Management group resource IDs produced by the governance module."
  value       = module.governance.management_group_resource_ids
}

output "policy_assignment_identity_ids" {
  description = "Principal IDs of policy managed identities. Feed into connectivity and monitoring roots for DNS zone and DCR role assignments."
  value       = module.governance.policy_assignment_identity_ids
}
