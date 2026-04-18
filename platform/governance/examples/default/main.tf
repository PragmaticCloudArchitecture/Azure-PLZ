# Minimal example — deploys the standard ALZ hierarchy with default settings.
#
# Prerequisites:
#   - The CI identity must have Owner at the tenant root management group.
#   - Set ARM_USE_OIDC=true and configure the azapi/azurerm providers via
#     environment variables (ARM_TENANT_ID, ARM_CLIENT_ID, etc.).
#
# This example intentionally leaves law_resource_id empty so it can run
# before tf-platform-monitoring is deployed. Wire the LAW ID in production.

module "governance" {
  source = "../.."

  location                     = var.location
  management_subscription_id   = var.management_subscription_id
  connectivity_subscription_id = var.connectivity_subscription_id
  identity_subscription_id     = var.identity_subscription_id

  # Leave unset to skip telemetry wiring until tf-platform-monitoring is ready.
  law_resource_id = ""

  # Adopt intermediate_root destroy behavior so subscriptions don't fall to
  # tenant root if this root module is ever torn down.
  subscription_placement_destroy_behavior = "intermediate_root"

  enable_telemetry = true
}
