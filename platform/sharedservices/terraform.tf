terraform {
  required_version = "~> 1.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
    # Remaining config supplied via -backend-config=env/${env}.backend.hcl:
    # resource_group_name  = "rg-tfstate-prod"
    # storage_account_name = "sttfstateprod001"
    # container_name       = "tfstate"
    # key                  = "platform/sharedservices.tfstate"
  }
}
