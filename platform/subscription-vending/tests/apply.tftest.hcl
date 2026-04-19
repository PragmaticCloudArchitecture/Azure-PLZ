# Smoke tests — requires real Azure credentials and a pre-existing subscription.
# Run: terraform test tests/apply.tftest.hcl
#
# Set ARM_TENANT_ID, ARM_CLIENT_ID, ARM_USE_OIDC=true in the environment.
# Supply real values for all required variables below.

variables {
  tenant_id                            = "<YOUR_TENANT_ID>"
  platform_management_subscription_id = "<YOUR_MGMT_SUB_ID>"
  connectivity_subscription_id         = "<YOUR_CONN_SUB_ID>"
  environment                          = "dev"
  location                             = "westeurope"
  billing_model                        = "Existing"
  subscription_id                      = "<YOUR_EXISTING_SUB_ID>"
  subscription_display_name            = "plz-smoke-test"
  subscription_workload                = "Production"
  management_group_id                  = "mg-sandboxes"
  tfstate_storage_account_name         = "<YOUR_TFSTATE_SA>"

  # Bypass remote state — supply values directly for smoke tests.
  connectivity_hub_virtual_network_id = "<HUB_VNET_RESOURCE_ID>"
  log_analytics_workspace_id          = "<LAW_RESOURCE_ID>"
  keyvault_id                         = "<KV_RESOURCE_ID>"
}

run "vend_existing_subscription" {
  command = apply

  assert {
    condition     = output.subscription_id != ""
    error_message = "Expected a non-empty subscription_id output."
  }

  assert {
    condition     = output.subscription_resource_id == "/subscriptions/${output.subscription_id}"
    error_message = "subscription_resource_id does not match expected format."
  }
}
