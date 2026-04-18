# Plan-only unit tests — no Azure credentials required.
# Run: terraform test tests/plan.tftest.hcl
#
# Both remote state data sources are bypassed via override variables so
# tfstate_rg / tfstate_sa are never contacted during unit tests.

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  sharedservices_subscription_id = "00000000-0000-0000-0000-000000000020"
  tenant_id                      = "00000000-0000-0000-0000-000000000001"
  client_id                      = "00000000-0000-0000-0000-000000000003"
  location                       = "westeurope"
  environment                    = "test"
  prefix                         = "plat"

  # Bypass remote state reads in tests
  log_analytics_workspace_id   = "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management"
  keyvault_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000011/resourceGroups/rg-plat-conn-test-westeurope/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
}

run "plan_succeeds_with_minimum_required_inputs" {
  command = plan
}

run "naming_convention_resource_group" {
  command = plan

  assert {
    condition     = local.ss_rg_name == "rg-plat-ss-test-westeurope"
    error_message = "Shared services RG name must follow the rg-plat-ss-{env}-{region} pattern."
  }
}

run "computed_keyvault_name_uses_prefix_and_environment" {
  command = plan

  assert {
    condition     = local.kv_name == "kv-plat-test"
    error_message = "Computed Key Vault name should be 'kv-{prefix}-{environment}'."
  }
}

run "explicit_keyvault_name_overrides_computed" {
  command = plan

  variables {
    keyvault_name = "kv-contoso-prod-001"
  }

  assert {
    condition     = local.kv_name == "kv-contoso-prod-001"
    error_message = "Explicit keyvault_name must override the computed default."
  }
}

run "pe_disabled_when_subnet_id_not_provided" {
  command = plan

  assert {
    condition     = local.pe_enabled == false
    error_message = "pe_enabled must be false when private_endpoint_subnet_id is null."
  }
}

run "pe_enabled_when_subnet_id_provided" {
  command = plan

  variables {
    private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000011/resourceGroups/rg-plat-conn-test-westeurope/providers/Microsoft.Network/virtualNetworks/vnet-plat-conn-test-westeurope/subnets/pe-subnet"
  }

  assert {
    condition     = local.pe_enabled == true
    error_message = "pe_enabled must be true when private_endpoint_subnet_id is set."
  }
}

run "law_override_variable_is_used_when_provided" {
  command = plan

  assert {
    condition     = local.law_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management"
    error_message = "law_resource_id local must reflect the override variable when it is set."
  }
}

run "law_empty_string_suppresses_diagnostic_setting" {
  command = plan

  variables {
    log_analytics_workspace_id = ""
  }

  assert {
    condition     = local.law_resource_id == ""
    error_message = "law_resource_id should be empty when override variable is an empty string."
  }
}

run "kv_dns_zone_override_is_used_when_provided" {
  command = plan

  assert {
    condition     = local.kv_private_dns_zone_id == "/subscriptions/00000000-0000-0000-0000-000000000011/resourceGroups/rg-plat-conn-test-westeurope/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    error_message = "kv_private_dns_zone_id local must reflect the override variable when it is set."
  }
}

run "standard_tags_present" {
  command = plan

  assert {
    condition     = local.tags["managed_by"] == "terraform"
    error_message = "Tags must include managed_by=terraform."
  }

  assert {
    condition     = local.tags["root_module"] == "tf-platform-sharedservices"
    error_message = "Tags must include root_module=tf-platform-sharedservices."
  }

  assert {
    condition     = local.tags["environment"] == "test"
    error_message = "Tags must include environment matching var.environment."
  }
}

run "caller_tags_merged_over_base_tags" {
  command = plan

  variables {
    tags = { costcenter = "CC-0200", managed_by = "override" }
  }

  assert {
    condition     = local.tags["costcenter"] == "CC-0200"
    error_message = "Caller-supplied tags must be present after merge."
  }

  assert {
    condition     = local.tags["managed_by"] == "override"
    error_message = "Caller-supplied tags must take precedence over base tags on key conflicts."
  }
}

run "validation_rejects_short_keyvault_name" {
  command = plan

  variables {
    keyvault_name = "ab"
  }

  expect_failures = [var.keyvault_name]
}

run "validation_rejects_long_keyvault_name" {
  command = plan

  variables {
    keyvault_name = "kv-this-name-is-way-too-long-for-azure"
  }

  expect_failures = [var.keyvault_name]
}

run "validation_rejects_invalid_sku" {
  command = plan

  variables {
    keyvault_sku = "enterprise"
  }

  expect_failures = [var.keyvault_sku]
}

run "validation_rejects_invalid_retention_days" {
  command = plan

  variables {
    keyvault_soft_delete_retention_days = 5
  }

  expect_failures = [var.keyvault_soft_delete_retention_days]
}

run "validation_rejects_invalid_law_id" {
  command = plan

  variables {
    log_analytics_workspace_id = "not-a-valid-resource-id"
  }

  expect_failures = [var.log_analytics_workspace_id]
}

run "validation_rejects_invalid_dns_zone_id" {
  command = plan

  variables {
    keyvault_private_dns_zone_id = "not-a-valid-resource-id"
  }

  expect_failures = [var.keyvault_private_dns_zone_id]
}
