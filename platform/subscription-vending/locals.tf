locals {
  # ---------------------------------------------------------------------------
  # Billing scope — resolved per billing_model; null for Existing subscriptions.
  # ---------------------------------------------------------------------------
  subscription_billing_scope = (
    var.billing_model == "EA"
    ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/enrollmentAccounts/${var.billing_enrollment_account}"
    : var.billing_model == "MCA"
      ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.billing_invoice_section_name}"
      : var.billing_model == "MPA"
        ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/customers/${var.billing_customer_name}"
        : null
  )

  # ---------------------------------------------------------------------------
  # Connectivity remote state resolution
  # ---------------------------------------------------------------------------
  _conn_outputs = try(one(data.terraform_remote_state.connectivity[*].outputs), null)

  hub_virtual_network_id = (
    var.connectivity_hub_virtual_network_id != null
    ? var.connectivity_hub_virtual_network_id
    : try(local._conn_outputs.hub_virtual_network_id, null)
  )

  private_dns_zone_ids = (
    length(var.private_dns_zone_ids) > 0
    ? var.private_dns_zone_ids
    : try(local._conn_outputs.private_dns_zone_ids, {})
  )

  # ---------------------------------------------------------------------------
  # Sharedservices remote state resolution
  # ---------------------------------------------------------------------------
  _ss_outputs = try(one(data.terraform_remote_state.sharedservices[*].outputs), null)

  keyvault_id = (
    var.keyvault_id != null
    ? var.keyvault_id
    : try(local._ss_outputs.keyvault_id, null)
  )

  # ---------------------------------------------------------------------------
  # Monitoring remote state resolution
  # ---------------------------------------------------------------------------
  _mon_outputs = try(one(data.terraform_remote_state.monitoring[*].outputs), null)

  law_resource_id = coalesce(
    var.log_analytics_workspace_id,
    try(local._mon_outputs.log_analytics_workspace_id, null),
    "",
  )

  # ---------------------------------------------------------------------------
  # Tags
  # ---------------------------------------------------------------------------
  base_tags = {
    managed_by   = "terraform"
    root_module  = "tf-subscription-vending"
    owner        = "central-it"
    environment  = var.environment
    subscription = var.subscription_display_name
  }
  tags = merge(local.base_tags, var.tags)
}
