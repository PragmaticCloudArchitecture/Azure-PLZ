provider "azurerm" {
  alias               = "connectivity"
  subscription_id     = var.connectivity_subscription_id
  tenant_id           = var.tenant_id
  client_id           = var.client_id
  use_oidc            = true
  storage_use_azuread = true
  features {}
}

# Default provider points at the same subscription so cross-sub data lookups
# (terraform_remote_state, governance outputs) work without an explicit alias.
provider "azurerm" {
  subscription_id     = var.connectivity_subscription_id
  tenant_id           = var.tenant_id
  client_id           = var.client_id
  use_oidc            = true
  storage_use_azuread = true
  features {}
}

provider "azapi" {
  subscription_id = var.connectivity_subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  use_oidc        = true
}
