# Unit tests — run with mocked providers, no real Azure calls required.
# Run: terraform test tests/unit/defaults.tftest.hcl

mock_provider "alz" {}

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000002"
      client_id       = "00000000-0000-0000-0000-000000000003"
    }
  }
}

mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location                     = "eastus"
  management_subscription_id   = "00000000-0000-0000-0000-000000000010"
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
  identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
  law_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management"
}

run "plan_succeeds_with_required_inputs_only" {
  command = plan
}

run "default_architecture_is_alz" {
  command = plan

  assert {
    condition     = var.architecture_name == "alz"
    error_message = "Default architecture_name must be 'alz'."
  }
}

run "default_destroy_behavior_is_intermediate_root" {
  command = plan

  assert {
    condition     = var.subscription_placement_destroy_behavior == "intermediate_root"
    error_message = "Default subscription_placement_destroy_behavior must be 'intermediate_root'."
  }
}

run "telemetry_enabled_by_default" {
  command = plan

  assert {
    condition     = var.enable_telemetry == true
    error_message = "enable_telemetry must default to true."
  }
}

run "authorization_required_for_group_creation_by_default" {
  command = plan

  assert {
    condition     = var.require_authorization_for_group_creation == true
    error_message = "require_authorization_for_group_creation must default to true."
  }
}

run "default_management_group_is_sandboxes" {
  command = plan

  assert {
    condition     = var.default_management_group_name == "alz-sandboxes"
    error_message = "default_management_group_name must default to 'alz-sandboxes'."
  }
}

run "library_references_built_from_alz_library_ref" {
  command = plan

  assert {
    condition     = local.library_references[0].path == "platform/alz"
    error_message = "library_references[0].path must be 'platform/alz'."
  }

  assert {
    condition     = local.library_references[0].ref == var.alz_library_ref
    error_message = "library_references[0].ref must equal var.alz_library_ref."
  }
}

run "subscription_placement_contains_three_platform_subs" {
  command = plan

  assert {
    condition     = contains(keys(local.subscription_placement), "management")
    error_message = "subscription_placement must contain a 'management' key."
  }

  assert {
    condition     = contains(keys(local.subscription_placement), "connectivity")
    error_message = "subscription_placement must contain a 'connectivity' key."
  }

  assert {
    condition     = contains(keys(local.subscription_placement), "identity")
    error_message = "subscription_placement must contain an 'identity' key."
  }
}

run "subscription_placement_uses_provided_subscription_ids" {
  command = plan

  assert {
    condition     = local.subscription_placement["management"].subscription_id == "00000000-0000-0000-0000-000000000010"
    error_message = "management subscription_id must match var.management_subscription_id."
  }

  assert {
    condition     = local.subscription_placement["connectivity"].subscription_id == "00000000-0000-0000-0000-000000000011"
    error_message = "connectivity subscription_id must match var.connectivity_subscription_id."
  }

  assert {
    condition     = local.subscription_placement["identity"].subscription_id == "00000000-0000-0000-0000-000000000012"
    error_message = "identity subscription_id must match var.identity_subscription_id."
  }
}

run "additional_subscription_placement_is_merged" {
  command = plan

  variables {
    additional_subscription_placement = {
      sandbox_extra = {
        subscription_id       = "00000000-0000-0000-0000-000000000099"
        management_group_name = "sandboxes"
      }
    }
  }

  assert {
    condition     = contains(keys(local.subscription_placement), "sandbox_extra")
    error_message = "additional_subscription_placement entries must be merged into local.subscription_placement."
  }
}

run "policy_default_values_contain_law_id" {
  command = plan

  assert {
    condition     = local.policy_default_values["log_analytics_workspace_id"] == jsonencode({ value = "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management" })
    error_message = "policy_default_values must encode law_resource_id under log_analytics_workspace_id."
  }
}

run "private_dns_zone_region_defaults_to_location" {
  command = plan

  assert {
    condition     = local.policy_default_values["private_dns_zone_region"] == jsonencode({ value = "eastus" })
    error_message = "private_dns_zone_region must default to var.location when not explicitly set."
  }
}
