data "azapi_client_config" "current" {}

module "alz" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "~> 0.19"

  architecture_name  = var.architecture_name
  location           = var.location
  parent_resource_id = data.azapi_client_config.current.tenant_id

  management_group_hierarchy_settings = {
    default_management_group_name            = var.default_management_group_name
    require_authorization_for_group_creation = var.require_authorization_for_group_creation
    update_existing                          = var.update_existing_management_groups
  }

  subscription_placement                  = local.subscription_placement
  subscription_placement_destroy_behavior = var.subscription_placement_destroy_behavior

  policy_default_values        = local.policy_default_values
  policy_assignments_to_modify = var.policy_assignments_to_modify

  management_group_role_assignments    = var.management_group_role_assignments
  role_assignment_name_use_random_uuid = true

  # Use *_dependencies in place of depends_on — the module does not support depends_on.
  management_groups_dependencies       = var.management_groups_dependencies
  policy_assignments_dependencies      = var.policy_assignments_dependencies
  policy_role_assignments_dependencies = var.policy_role_assignments_dependencies

  enable_telemetry = var.enable_telemetry
}
