variable "tenant_id" {
  description = "The Entra ID tenant ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid UUID."
  }
}

variable "platform_management_subscription_id" {
  description = "Subscription ID for the management (pivot) subscription — used by the Terraform backend and cross-sub RBAC assignments."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.platform_management_subscription_id))
    error_message = "platform_management_subscription_id must be a valid UUID."
  }
}

variable "connectivity_subscription_id" {
  description = "Subscription ID for the connectivity subscription (hub VNet, private DNS zones)."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.connectivity_subscription_id))
    error_message = "connectivity_subscription_id must be a valid UUID."
  }
}

variable "environment" {
  description = "Deployment environment label (prod, nonprod, dev, test, or staging)."
  type        = string
  validation {
    condition     = contains(["prod", "nonprod", "dev", "test", "staging"], var.environment)
    error_message = "environment must be one of: prod, nonprod, dev, test, staging."
  }
}

variable "location" {
  description = "Primary Azure region for resources created in the vended subscription."
  type        = string
}

variable "tfstate_resource_group_name" {
  description = "Resource group name containing the Terraform state storage account."
  type        = string
  default     = "rg-tfstate-platform"
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state."
  type        = string
  default     = null
}

variable "tfstate_container_name" {
  description = "Storage container name for Terraform state blobs."
  type        = string
  default     = "tfstate"
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace for subscription activity log diagnostics. If null, read from tf-platform-monitoring remote state."
  type        = string
  default     = null
  validation {
    condition = var.log_analytics_workspace_id == null || can(
      regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.OperationalInsights/workspaces/[^/]+$",
      var.log_analytics_workspace_id)
    )
    error_message = "log_analytics_workspace_id must be a valid Log Analytics workspace resource ID."
  }
}

variable "enable_telemetry" {
  description = "Enable AVM telemetry (anonymous usage data sent to Microsoft)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to merge onto all resources."
  type        = map(string)
  default     = {}
}
