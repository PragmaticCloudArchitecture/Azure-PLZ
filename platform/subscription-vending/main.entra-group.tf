locals {
  # Well-known Azure built-in role definition GUIDs.
  role_definition_ids = {
    "Owner"       = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    "Contributor" = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    "Reader"      = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
  }
}

resource "azuread_group" "workload_team" {
  count = var.create_entra_group ? 1 : 0

  display_name     = coalesce(var.entra_group_display_name, "grp-sub-${replace(lower(var.subscription_display_name), " ", "-")}")
  mail_enabled     = false
  security_enabled = true
  owners           = var.entra_group_owners
}

resource "random_uuid" "entra_group_role_assignment" {
  count = var.create_entra_group ? 1 : 0
}

resource "azapi_resource" "entra_group_role_assignment" {
  count = var.create_entra_group ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.entra_group_role_assignment[0].result
  parent_id = "/subscriptions/${module.vending.subscription_id}"

  body = {
    properties = {
      principalId      = azuread_group.workload_team[0].object_id
      principalType    = "Group"
      roleDefinitionId = "/subscriptions/${module.vending.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.role_definition_ids[var.entra_group_role_definition_name]}"
    }
  }

  depends_on = [module.vending]
}
