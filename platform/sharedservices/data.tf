# Read the central Log Analytics workspace ID from tf-platform-monitoring remote state.
# Skipped when var.log_analytics_workspace_id is set (override mode) — used in tests
# and CI pipelines that read remote state externally.
data "terraform_remote_state" "monitoring" {
  count = var.log_analytics_workspace_id == null ? 1 : 0

  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_rg
    storage_account_name = var.tfstate_sa
    container_name       = "tfstate"
    key                  = "platform/monitoring.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

# Read the Key Vault private DNS zone ID from tf-platform-connectivity remote state.
# Skipped when var.keyvault_private_dns_zone_id is set (override mode).
data "terraform_remote_state" "connectivity" {
  count = var.keyvault_private_dns_zone_id == null ? 1 : 0

  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_rg
    storage_account_name = var.tfstate_sa
    container_name       = "tfstate"
    key                  = "platform/connectivity.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
