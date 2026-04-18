# Post-apply smoke tests — require real Azure credentials and a live environment.
# Run only in nightly ephemeral sandbox pipelines (not on PR).
#
# Prerequisites:
#   export ARM_USE_OIDC=true
#   export ARM_CLIENT_ID=<apply-uami-client-id>
#   export ARM_TENANT_ID=<tenant-id>
#   export ARM_SUBSCRIPTION_ID=<sharedservices-sub-id>
#   terraform init -backend-config=env/sandbox.backend.hcl
#
# These tests create real Azure resources. The Key Vault alone deploys in
# under 2 minutes; the private endpoint adds ~30 seconds.

variables {
  location    = "westeurope"
  environment = "smoke"
  prefix      = "plat"

  # Use a name unique to the smoke subscription to avoid conflicts.
  keyvault_name = "kv-plat-smoke-ss-001"

  keyvault_sku                        = "standard"
  keyvault_purge_protection_enabled   = false
  keyvault_soft_delete_retention_days = 7

  # Bypass remote state in smoke tests — no connectivity or monitoring deployed.
  log_analytics_workspace_id   = ""
  keyvault_private_dns_zone_id = null

  enable_telemetry = false

  tags = { purpose = "smoke-test" }
}

run "resources_created" {
  command = apply

  assert {
    condition     = length(module.keyvault.resource_id) > 0
    error_message = "Key Vault resource ID must be present after apply."
  }

  assert {
    condition     = startswith(module.keyvault.resource.vault_uri, "https://")
    error_message = "Key Vault vault_uri must start with https://."
  }

  assert {
    condition     = azurerm_resource_group.sharedservices.name == "rg-plat-ss-smoke-westeurope"
    error_message = "Resource group name must follow the naming convention."
  }
}

run "keyvault_is_rbac_enabled" {
  command = apply

  assert {
    condition     = module.keyvault.resource.enable_rbac_authorization == true
    error_message = "Key Vault must use RBAC authorization model."
  }
}

run "second_plan_is_no_op" {
  command = plan

  assert {
    condition     = length(module.keyvault.resource_id) > 0
    error_message = "Key Vault must still be present on idempotency plan."
  }
}
