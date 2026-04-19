terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.35"
      configuration_aliases = [azurerm.connectivity]
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.5"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
    # Remaining config supplied via -backend-config in CI.
    # State key is per-vended-subscription: subvending/<env>/<subscription_name>.tfstate
    # tenant_id            = "..."
    # subscription_id      = "..."    # management pivot subscription
    # resource_group_name  = "rg-tfstate-platform"
    # storage_account_name = "sttfstateplatform"
    # container_name       = "tfstate"
    # key                  = "subvending/prod/my-app.tfstate"
  }
}
