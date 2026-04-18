locals {
  library_references = [
    {
      path = "platform/alz"
      ref  = var.alz_library_ref
    }
  ]

  # Build subscription placement from individual platform subscription ID variables,
  # then merge any caller-supplied additions. Callers can override a key by including
  # it in var.additional_subscription_placement.
  subscription_placement = merge(
    {
      management = {
        subscription_id       = var.management_subscription_id
        management_group_name = "management"
      }
      connectivity = {
        subscription_id       = var.connectivity_subscription_id
        management_group_name = "connectivity"
      }
      identity = {
        subscription_id       = var.identity_subscription_id
        management_group_name = "identity"
      }
    },
    var.additional_subscription_placement
  )

  # Every policy default value must be jsonencode({ value = ... })-wrapped per the
  # module contract. Callers supply additional_policy_default_values in the same form.
  policy_default_values = merge(
    {
      log_analytics_workspace_id = jsonencode({ value = var.law_resource_id })
      ddos_protection_plan_id    = jsonencode({ value = var.ddos_protection_plan_id })
      private_dns_zone_region    = jsonencode({ value = coalesce(var.private_dns_zone_region, var.location) })
    },
    var.additional_policy_default_values
  )
}
