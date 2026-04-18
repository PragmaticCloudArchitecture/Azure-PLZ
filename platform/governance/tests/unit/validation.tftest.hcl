# Validation tests — verify that input validation rules reject bad values.
# Run: terraform test tests/unit/validation.tftest.hcl

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

run "invalid_destroy_behavior_rejected" {
  command = plan

  variables {
    location                                = "eastus"
    management_subscription_id              = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id            = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id                = "00000000-0000-0000-0000-000000000012"
    subscription_placement_destroy_behavior = "nowhere"
  }

  expect_failures = [var.subscription_placement_destroy_behavior]
}

run "invalid_management_subscription_id_rejected" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "not-a-uuid"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
  }

  expect_failures = [var.management_subscription_id]
}

run "invalid_connectivity_subscription_id_rejected" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
  }

  expect_failures = [var.connectivity_subscription_id]
}

run "invalid_identity_subscription_id_rejected" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "12345"
  }

  expect_failures = [var.identity_subscription_id]
}

run "invalid_law_resource_id_rejected" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
    law_resource_id              = "not-a-valid-resource-id"
  }

  expect_failures = [var.law_resource_id]
}

run "empty_law_resource_id_accepted" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
    law_resource_id              = ""
  }
}

run "invalid_location_with_uppercase_rejected" {
  command = plan

  variables {
    location                     = "EastUS"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
  }

  expect_failures = [var.location]
}

run "invalid_architecture_name_with_spaces_rejected" {
  command = plan

  variables {
    location                     = "eastus"
    management_subscription_id   = "00000000-0000-0000-0000-000000000010"
    connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
    identity_subscription_id     = "00000000-0000-0000-0000-000000000012"
    architecture_name            = "my architecture"
  }

  expect_failures = [var.architecture_name]
}
