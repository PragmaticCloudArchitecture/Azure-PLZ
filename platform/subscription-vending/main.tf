module "vending" {
  source  = "Azure/avm-ptn-alz-sub-vending/azure"
  version = "= 0.2.0"

  # Subscription identity
  subscription_alias_enabled = var.billing_model != "Existing"
  subscription_display_name  = var.subscription_display_name
  subscription_alias_name    = replace(lower(var.subscription_display_name), " ", "-")
  subscription_billing_scope = local.subscription_billing_scope
  subscription_workload      = var.subscription_workload

  # Existing subscription adoption
  subscription_id = var.subscription_id

  # Management group placement
  subscription_management_group_association_enabled = true
  subscription_management_group_id                  = var.management_group_id

  # Tags applied to the subscription resource
  subscription_tags = merge(local.tags, var.subscription_tags)

  # Virtual network
  virtual_network_enabled = var.create_virtual_network && length(var.virtual_network_address_space) > 0

  virtual_networks = var.create_virtual_network && length(var.virtual_network_address_space) > 0 ? {
    default = {
      name                = "vnet-${replace(lower(var.subscription_display_name), " ", "-")}-${var.environment}"
      address_space       = var.virtual_network_address_space
      location            = var.location
      resource_group_name = "rg-networking-${var.environment}"

      hub_network_resource_id             = local.hub_virtual_network_id
      hub_peering_enabled                 = var.hub_peering_enabled
      hub_peering_use_remote_gateways     = var.hub_peering_use_remote_gateways
      hub_peering_allow_forwarded_traffic = var.hub_peering_allow_forwarded_traffic
    }
  } : {}

  # Role assignments on the subscription scope
  role_assignment_enabled = length(var.role_assignments) > 0
  role_assignments        = var.role_assignments

  # Workload identity — UAMI + federated credentials via AzAPI (no azurerm.vended needed)
  umi_enabled = var.create_workload_identity

  user_managed_identities = var.create_workload_identity ? {
    default = {
      name                = coalesce(var.workload_identity_name, "uami-cicd-${replace(lower(var.subscription_display_name), " ", "-")}")
      resource_group_name = "rg-identity-${var.environment}"
      location            = var.location

      federated_identity_credentials = length(var.workload_identity_federated_credentials) > 0 ? (
        var.workload_identity_federated_credentials
      ) : (
        var.github_organization != null && var.github_repository != null ? {
          github-actions = {
            audiences = ["api://AzureADTokenExchange"]
            issuer    = "https://token.actions.githubusercontent.com"
            subject = var.github_environment != null ? (
              "repo:${var.github_organization}/${var.github_repository}:environment:${var.github_environment}"
            ) : (
              "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/main"
            )
          }
        } : {}
      )
    }
  } : {}

  enable_telemetry = var.enable_telemetry

  lifecycle {
    precondition {
      condition = !(var.billing_model == "EA" && (
        var.billing_account_name == null || var.billing_enrollment_account == null
      ))
      error_message = "billing_model = 'EA' requires billing_account_name and billing_enrollment_account."
    }
    precondition {
      condition = !(var.billing_model == "MCA" && (
        var.billing_account_name == null || var.billing_profile_name == null || var.billing_invoice_section_name == null
      ))
      error_message = "billing_model = 'MCA' requires billing_account_name, billing_profile_name, and billing_invoice_section_name."
    }
    precondition {
      condition = !(var.billing_model == "MPA" && (
        var.billing_account_name == null || var.billing_customer_name == null
      ))
      error_message = "billing_model = 'MPA' requires billing_account_name and billing_customer_name."
    }
    precondition {
      condition     = !(var.billing_model == "Existing" && var.subscription_id == null)
      error_message = "billing_model = 'Existing' requires subscription_id."
    }
  }
}
