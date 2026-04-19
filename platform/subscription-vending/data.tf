data "terraform_remote_state" "connectivity" {
  count   = var.connectivity_hub_virtual_network_id == null ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "platform/connectivity.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "sharedservices" {
  count   = var.keyvault_id == null ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "platform/sharedservices.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "monitoring" {
  count   = var.log_analytics_workspace_id == null ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "platform/monitoring.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
