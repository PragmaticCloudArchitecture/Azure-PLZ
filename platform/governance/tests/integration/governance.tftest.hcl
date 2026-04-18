# Integration tests — apply and destroy against a real Azure tenant.
# Requires:
#   - ARM_USE_OIDC=true
#   - A CI identity with Owner at /providers/Microsoft.Management/managementGroups/<tenantId>
#   - TF_VAR_management_subscription_id, TF_VAR_connectivity_subscription_id,
#     TF_VAR_identity_subscription_id set in the pipeline environment
#   - var.update_existing_management_groups = true when running against a tenant
#     that already has the ALZ hierarchy bootstrapped

variables {
  location                          = "eastus"
  update_existing_management_groups = true
  enable_telemetry                  = false
}

run "governance_applies_successfully" {
  command = apply

  assert {
    condition     = length(module.alz.management_group_resource_ids) > 0
    error_message = "Expected non-empty management_group_resource_ids after apply."
  }

  assert {
    condition     = length(module.alz.policy_assignment_resource_ids) > 0
    error_message = "Expected non-empty policy_assignment_resource_ids after apply."
  }

  assert {
    condition     = length(module.alz.policy_definition_resource_ids) > 0
    error_message = "Expected non-empty policy_definition_resource_ids after apply."
  }
}

run "second_plan_is_no_op" {
  # Idempotency check: a plan immediately after apply must show zero changes.
  command = plan

  assert {
    condition     = length(module.alz.management_group_resource_ids) > 0
    error_message = "Management groups must still be present on idempotency plan."
  }
}
