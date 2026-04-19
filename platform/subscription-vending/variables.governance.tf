variable "management_group_id" {
  description = "Management group ID (without prefix) to place the vended subscription into."
  type        = string
  validation {
    condition     = length(var.management_group_id) >= 1
    error_message = "management_group_id must not be empty."
  }
}

variable "subscription_tags" {
  description = "Tags to apply directly to the subscription resource (in addition to var.tags)."
  type        = map(string)
  default     = {}
}

variable "role_assignments" {
  description = "Map of role assignments to create on the vended subscription. Key is an arbitrary stable label."
  type = map(object({
    principal_id         = string
    role_definition_name = optional(string)
    role_definition_id   = optional(string)
  }))
  default = {}
}

variable "budget_amount" {
  description = "Monthly budget amount in USD. Set to null to disable budget creation."
  type        = number
  default     = null
}

variable "budget_alert_emails" {
  description = "Email addresses to notify when the subscription budget threshold is reached."
  type        = list(string)
  default     = []
}

variable "keyvault_id" {
  description = "Resource ID of the platform Key Vault. If null, read from tf-platform-sharedservices remote state."
  type        = string
  default     = null
  validation {
    condition = var.keyvault_id == null || can(
      regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.KeyVault/vaults/[^/]+$",
      var.keyvault_id)
    )
    error_message = "keyvault_id must be a valid Key Vault resource ID."
  }
}
