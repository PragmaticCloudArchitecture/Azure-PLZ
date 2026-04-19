provider "azurerm" {
  subscription_id     = var.platform_management_subscription_id
  tenant_id           = var.tenant_id
  use_oidc            = true
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azurerm" {
  alias               = "connectivity"
  subscription_id     = var.connectivity_subscription_id
  tenant_id           = var.tenant_id
  use_oidc            = true
  features {}
}

provider "azapi" {
  tenant_id = var.tenant_id
  use_oidc  = true
}

provider "azuread" {
  tenant_id = var.tenant_id
  use_oidc  = true
}
