# Unit tests — mocked providers, no Azure credentials required.
# Run: terraform test tests/plan.tftest.hcl

mock_provider "azurerm" {}
mock_provider "azapi"   {}
mock_provider "azuread" {}
mock_provider "random"  {}
mock_provider "modtm"   {}
mock_provider "time"    {}

# Supply direct values for all remote-state-derived variables so that
# count = 0 on all data.terraform_remote_state sources (no backend needed).
variables {
  tenant_id                            = "00000000-0000-0000-0000-000000000001"
  platform_management_subscription_id = "00000000-0000-0000-0000-000000000002"
  connectivity_subscription_id         = "00000000-0000-0000-0000-000000000003"
  environment                          = "dev"
  location                             = "westeurope"
  billing_model                        = "Existing"
  subscription_id                      = "00000000-0000-0000-0000-000000000004"
  subscription_display_name            = "test-subscription"
  subscription_workload                = "Production"
  management_group_id                  = "mg-test"
  tfstate_storage_account_name         = "sttfstatetest"

  # Override remote-state-derived values directly to avoid backend connectivity.
  connectivity_hub_virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-conn/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  keyvault_id                         = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-ss/providers/Microsoft.KeyVault/vaults/kv-test"
  log_analytics_workspace_id          = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-mon/providers/Microsoft.OperationalInsights/workspaces/law-test"
}

# ---------------------------------------------------------------------------
# Validation: billing_model EA requires billing_account_name
# ---------------------------------------------------------------------------
run "ea_billing_requires_account_name" {
  command = plan
  variables {
    billing_model              = "EA"
    subscription_id            = null
    billing_enrollment_account = "123456789"
    # billing_account_name left null — should trigger precondition
  }
  expect_failures = [module.vending]
}

# ---------------------------------------------------------------------------
# Validation: billing_model MCA requires all three MCA fields
# ---------------------------------------------------------------------------
run "mca_billing_requires_all_fields" {
  command = plan
  variables {
    billing_model        = "MCA"
    subscription_id      = null
    billing_account_name = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    # billing_profile_name and billing_invoice_section_name left null
  }
  expect_failures = [module.vending]
}

# ---------------------------------------------------------------------------
# Validation: billing_model MPA requires billing_account_name and billing_customer_name
# ---------------------------------------------------------------------------
run "mpa_billing_requires_customer_name" {
  command = plan
  variables {
    billing_model        = "MPA"
    subscription_id      = null
    billing_account_name = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    # billing_customer_name left null
  }
  expect_failures = [module.vending]
}

# ---------------------------------------------------------------------------
# Validation: billing_model Existing requires subscription_id
# ---------------------------------------------------------------------------
run "existing_billing_requires_subscription_id" {
  command = plan
  variables {
    billing_model   = "Existing"
    subscription_id = null
  }
  expect_failures = [module.vending]
}

# ---------------------------------------------------------------------------
# Validation: unknown billing_model value rejected by variable validation
# ---------------------------------------------------------------------------
run "invalid_billing_model_rejected" {
  command = plan
  variables {
    billing_model = "CSP"
  }
  expect_failures = [var.billing_model]
}

# ---------------------------------------------------------------------------
# Validation: unknown environment value rejected
# ---------------------------------------------------------------------------
run "invalid_environment_rejected" {
  command = plan
  variables {
    environment = "qa-xyz-not-valid"
  }
  expect_failures = [var.environment]
}

# ---------------------------------------------------------------------------
# Validation: malformed tenant_id rejected
# ---------------------------------------------------------------------------
run "invalid_tenant_id_format" {
  command = plan
  variables {
    tenant_id = "not-a-valid-uuid"
  }
  expect_failures = [var.tenant_id]
}

# ---------------------------------------------------------------------------
# Validation: malformed subscription_id rejected
# ---------------------------------------------------------------------------
run "invalid_subscription_id_format" {
  command = plan
  variables {
    subscription_id = "bad-id-format"
  }
  expect_failures = [var.subscription_id]
}

# ---------------------------------------------------------------------------
# Validation: invalid entra_group_role_definition_name rejected
# ---------------------------------------------------------------------------
run "invalid_entra_group_role_rejected" {
  command = plan
  variables {
    create_entra_group               = true
    entra_group_role_definition_name = "StorageBlobDataOwner"
  }
  expect_failures = [var.entra_group_role_definition_name]
}

# ---------------------------------------------------------------------------
# Plan: basic Existing subscription plan succeeds
# ---------------------------------------------------------------------------
run "basic_existing_subscription_plan" {
  command = plan
}

# ---------------------------------------------------------------------------
# Plan: EA billing with all required fields
# ---------------------------------------------------------------------------
run "ea_billing_all_fields_plan" {
  command = plan
  variables {
    billing_model              = "EA"
    subscription_id            = null
    billing_account_name       = "12345678"
    billing_enrollment_account = "987654321"
  }
}

# ---------------------------------------------------------------------------
# Plan: VNet with hub peering enabled
# ---------------------------------------------------------------------------
run "vnet_with_hub_peering" {
  command = plan
  variables {
    create_virtual_network        = true
    virtual_network_address_space = ["10.100.0.0/24"]
    hub_peering_enabled           = true
  }
}

# ---------------------------------------------------------------------------
# Plan: workload identity with GitHub federated credential
# ---------------------------------------------------------------------------
run "workload_identity_github_fed_cred" {
  command = plan
  variables {
    create_workload_identity = true
    github_organization      = "my-org"
    github_repository        = "my-app"
    github_environment       = "production"
  }
}

# ---------------------------------------------------------------------------
# Plan: Entra group enabled
# ---------------------------------------------------------------------------
run "entra_group_enabled_plan" {
  command = plan
  variables {
    create_entra_group = true
  }
}

# ---------------------------------------------------------------------------
# Plan: no VNet when address space is empty
# ---------------------------------------------------------------------------
run "no_vnet_without_address_space" {
  command = plan
  variables {
    create_virtual_network        = true
    virtual_network_address_space = []
  }
}
