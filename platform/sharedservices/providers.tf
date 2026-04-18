provider "azurerm" {
  alias               = "sharedservices"
  subscription_id     = var.sharedservices_subscription_id
  tenant_id           = var.tenant_id
  client_id           = var.client_id
  use_oidc            = true
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Default provider targets the same subscription so remote-state reads and
# any data lookups work without an explicit alias.
provider "azurerm" {
  subscription_id     = var.sharedservices_subscription_id
  tenant_id           = var.tenant_id
  client_id           = var.client_id
  use_oidc            = true
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azapi" {
  subscription_id = var.sharedservices_subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  use_oidc        = true
}
