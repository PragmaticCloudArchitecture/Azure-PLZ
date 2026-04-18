# ---------------------------------------------------------------------------
# Required
# ---------------------------------------------------------------------------

variable "location" {
  type        = string
  description = "Azure region where policy user-assigned managed identities and any region-scoped resources will be deployed. Example: 'eastus', 'westeurope'."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "location must be a lowercase Azure region name with no spaces or hyphens (e.g., 'eastus', 'westeurope', 'australiaeast')."
  }
}

variable "management_subscription_id" {
  type        = string
  description = "Subscription ID for the management platform subscription. This subscription hosts Log Analytics, Automation, and other central management resources."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.management_subscription_id))
    error_message = "management_subscription_id must be a valid lowercase UUID (e.g., '00000000-0000-0000-0000-000000000000')."
  }
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Subscription ID for the connectivity platform subscription. This subscription hosts the hub VNet, firewall, Bastion, and DNS."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.connectivity_subscription_id))
    error_message = "connectivity_subscription_id must be a valid lowercase UUID (e.g., '00000000-0000-0000-0000-000000000000')."
  }
}

variable "identity_subscription_id" {
  type        = string
  description = "Subscription ID for the identity platform subscription. This subscription hosts AD DS domain controllers or other identity workloads."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.identity_subscription_id))
    error_message = "identity_subscription_id must be a valid lowercase UUID (e.g., '00000000-0000-0000-0000-000000000000')."
  }
}

# ---------------------------------------------------------------------------
# ALZ library and architecture
# ---------------------------------------------------------------------------

variable "architecture_name" {
  type        = string
  description = "Name of the ALZ architecture definition to deploy. Must match a '<name>.alz_architecture_definition.{json,yaml,yml}' file in the referenced library. Use 'alz' for the default ALZ hierarchy."
  default     = "alz"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.architecture_name))
    error_message = "architecture_name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "alz_library_ref" {
  type        = string
  description = "Git ref (tag) of the ALZ Library to download at init time. Pin this explicitly and treat upgrades as deliberate change events — downstream subscriptions inherit library changes immediately."
  default     = "2026.01.3"
}

# ---------------------------------------------------------------------------
# Management group settings
# ---------------------------------------------------------------------------

variable "default_management_group_name" {
  type        = string
  description = "Name of the management group that new subscriptions land in by default when not explicitly placed via subscription_placement."
  default     = "alz-sandboxes"
}

variable "require_authorization_for_group_creation" {
  type        = bool
  description = "When true, only principals with explicit permission can create new management groups under the tenant root. Recommended true for production tenants."
  default     = true
}

variable "update_existing_management_groups" {
  type        = bool
  description = "Set true when adopting an existing tenant with a management group hierarchy already in place. Setting false on an existing tenant will cause plan failures."
  default     = false
}

# ---------------------------------------------------------------------------
# Subscription placement
# ---------------------------------------------------------------------------

variable "additional_subscription_placement" {
  type = map(object({
    subscription_id       = string
    management_group_name = string
  }))
  description = "Additional subscriptions to place under management groups, merged with the default management/connectivity/identity placement. Use this to place sandbox or early workload subscriptions during bootstrapping."
  default     = {}
}

variable "subscription_placement_destroy_behavior" {
  type        = string
  description = "Controls where subscriptions are re-parented when removed from Terraform state. 'intermediate_root' prevents accidental return to tenant root. One of: default, parent, intermediate_root, custom."
  default     = "intermediate_root"

  validation {
    condition     = contains(["default", "parent", "intermediate_root", "custom"], var.subscription_placement_destroy_behavior)
    error_message = "subscription_placement_destroy_behavior must be one of: default, parent, intermediate_root, custom."
  }
}

# ---------------------------------------------------------------------------
# Policy default values
# ---------------------------------------------------------------------------

variable "law_resource_id" {
  type        = string
  description = "Resource ID of the central Log Analytics workspace used in policy default values to route diagnostic data. Provide after tf-platform-monitoring is applied. Use an empty string to defer wiring."
  default     = ""

  validation {
    condition = (
      var.law_resource_id == "" ||
      can(regex(
        "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$",
        var.law_resource_id
      ))
    )
    error_message = "law_resource_id must be a valid Log Analytics workspace resource ID or an empty string."
  }
}

variable "automation_account_resource_id" {
  type        = string
  description = "Resource ID of the central Automation Account. Passed into policy_assignments_dependencies to gate policy assignments on its provisioning."
  default     = ""
}

variable "ddos_protection_plan_id" {
  type        = string
  description = "Resource ID of an existing Azure DDoS Network Protection Plan. Leave empty to disable DDoS policy enforcement."
  default     = ""
}

variable "private_dns_zone_region" {
  type        = string
  description = "Azure region used in private DNS zone policy defaults. Defaults to var.location when null."
  default     = null
}

variable "additional_policy_default_values" {
  type        = map(string)
  description = "Additional policy default values merged with the standard set. All values must be jsonencode({ value = ... })-wrapped strings to satisfy the ALZ module contract."
  default     = {}
}

# ---------------------------------------------------------------------------
# Policy assignment overrides
# ---------------------------------------------------------------------------

variable "policy_assignments_to_modify" {
  type        = any
  description = <<-EOT
    Two-level map that overrides policy assignments per management group. Structure:

    {
      <management_group_id> = {
        policy_assignments = {
          <assignment_name> = {
            enforcement_mode        = optional(string)          # "Default" | "DoNotEnforce"
            identity                = optional(string)          # "SystemAssigned" | "UserAssigned" | "None"
            identity_ids            = optional(list(string))    # UAMI resource IDs when identity = "UserAssigned"
            parameters              = optional(map(string))     # values must be jsonencode({ value = ... })
            non_compliance_messages = optional(map(string))
            resource_selectors      = optional(any)
            overrides               = optional(any)
            creation_enabled        = optional(bool)
          }
        }
      }
    }
  EOT
  default     = {}
}

# ---------------------------------------------------------------------------
# RBAC
# ---------------------------------------------------------------------------

variable "management_group_role_assignments" {
  type = map(object({
    management_group_name                  = string
    role_definition_id_or_name             = string
    principal_id                           = string
    principal_type                         = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, false)
    delegated_managed_identity_resource_id = optional(string)
  }))
  description = "Map of management-group-scoped RBAC role assignments. role_definition_id_or_name accepts built-in names (e.g., 'Owner') or full definition resource IDs."
  default     = {}
}

# ---------------------------------------------------------------------------
# Dependency sequencing (replaces depends_on — not supported by this module)
# ---------------------------------------------------------------------------

variable "management_groups_dependencies" {
  type        = list(any)
  description = "Opaque list passed to the module's management_groups_dependencies input. Include resource IDs or outputs from other roots that must exist before management groups are written."
  default     = []
}

variable "policy_assignments_dependencies" {
  type        = list(any)
  description = "Opaque list passed to the module's policy_assignments_dependencies input. Include the LAW resource ID and Automation Account resource ID so policy assignments are not created until those resources exist."
  default     = []
}

variable "policy_role_assignments_dependencies" {
  type        = list(any)
  description = "Opaque list passed to the module's policy_role_assignments_dependencies input. Include resource IDs that policy-managed identities need before role assignments are created."
  default     = []
}

# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------

variable "enable_telemetry" {
  type        = bool
  description = "Set false to opt out of Microsoft usage telemetry. Required false in regulated or air-gapped tenants."
  default     = true
}
