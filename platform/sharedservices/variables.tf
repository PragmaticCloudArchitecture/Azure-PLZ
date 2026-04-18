# ---------------------------------------------------------------------------
# Identity and authentication
# ---------------------------------------------------------------------------

variable "sharedservices_subscription_id" {
  type        = string
  description = "Subscription ID where all shared services resources are deployed."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.sharedservices_subscription_id))
    error_message = "sharedservices_subscription_id must be a valid lowercase UUID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID. Used in provider OIDC configuration and Key Vault tenant binding."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid lowercase UUID."
  }
}

variable "client_id" {
  type        = string
  description = "Client ID of the User-Assigned Managed Identity used by the CI runner for OIDC authentication."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.client_id))
    error_message = "client_id must be a valid lowercase UUID."
  }
}

# ---------------------------------------------------------------------------
# Deployment location and environment
# ---------------------------------------------------------------------------

variable "location" {
  type        = string
  description = "Azure region where all shared services resources are deployed. Example: 'westeurope', 'eastus'."
  default     = "westeurope"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "location must be a lowercase Azure region name with no spaces or hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Short environment label used in resource naming. Lowercase letters, numbers, and hyphens only."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "environment must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "prefix" {
  type        = string
  description = "Short alphanumeric prefix used in generated resource names (e.g., 'alz', 'plat', 'contoso'). Max 8 chars."
  default     = "plat"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.prefix))
    error_message = "prefix must be 2-8 lowercase alphanumeric characters starting with a letter."
  }
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------

variable "keyvault_name" {
  type        = string
  description = <<-EOT
    Name of the shared Key Vault. Must be 3-24 alphanumeric+hyphen characters, globally unique.
    When null the name is computed as 'kv-{prefix}-{environment}' — suitable for tests but
    NOT globally unique; always set this explicitly in production deployments.
  EOT
  default     = null

  validation {
    condition = (
      var.keyvault_name == null ||
      (
        length(var.keyvault_name) >= 3 &&
        length(var.keyvault_name) <= 24 &&
        can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.keyvault_name))
      )
    )
    error_message = "keyvault_name must be 3-24 characters, start with a letter, end with a letter or digit, and contain only letters, digits, and hyphens."
  }
}

variable "keyvault_sku" {
  type        = string
  description = "Key Vault SKU. 'standard' is sufficient for secrets and certificates; 'premium' adds HSM-backed keys."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.keyvault_sku)
    error_message = "keyvault_sku must be 'standard' or 'premium'."
  }
}

variable "keyvault_purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection. When true, a deleted vault and its objects cannot be permanently deleted during the soft-delete retention period. Recommended for production."
  default     = true
}

variable "keyvault_soft_delete_retention_days" {
  type        = number
  description = "Number of days that soft-deleted vaults and objects are retained. Valid range: 7-90."
  default     = 90

  validation {
    condition     = var.keyvault_soft_delete_retention_days >= 7 && var.keyvault_soft_delete_retention_days <= 90
    error_message = "keyvault_soft_delete_retention_days must be between 7 and 90."
  }
}

variable "keyvault_public_network_access_enabled" {
  type        = bool
  description = "Allow public network access to the Key Vault when no private endpoint is configured. Has no effect when private_endpoint_subnet_id is set (public access is always disabled with a PE)."
  default     = false
}

variable "keyvault_ip_rules" {
  type        = list(string)
  description = "List of CIDR ranges or IPv4 addresses permitted through the Key Vault firewall when a private endpoint is configured. AzureServices bypass is always enabled."
  default     = []
}

# ---------------------------------------------------------------------------
# Private endpoint
# ---------------------------------------------------------------------------

variable "private_endpoint_subnet_id" {
  type        = string
  description = <<-EOT
    Resource ID of the subnet where the Key Vault private endpoint is placed.
    When null (default) no private endpoint is created and the Key Vault is accessible
    via its public endpoint (subject to keyvault_public_network_access_enabled).
    Typical value: a PE subnet in the hub VNet created outside this root.
  EOT
  default     = null
}

variable "keyvault_private_dns_zone_id" {
  type        = string
  description = <<-EOT
    Resource ID of the 'privatelink.vaultcore.azure.net' private DNS zone to link with the
    private endpoint. When null the zone ID is read from tf-platform-connectivity remote state.
    Set explicitly in tests or CI pipelines that do not have access to the connectivity state.
    If null and remote state is unavailable, the PE is created without a DNS zone group.
  EOT
  default     = null

  validation {
    condition = (
      var.keyvault_private_dns_zone_id == null ||
      can(regex(
        "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$",
        var.keyvault_private_dns_zone_id
      ))
    )
    error_message = "keyvault_private_dns_zone_id must be a valid Private DNS Zone resource ID or null."
  }
}

# ---------------------------------------------------------------------------
# Monitoring integration
# ---------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  type        = string
  description = <<-EOT
    Override: Resource ID of the central Log Analytics workspace from tf-platform-monitoring.
    When set, the monitoring remote state data source is skipped entirely.
    When null (default), the workspace ID is read from the monitoring remote state.
    Set to an empty string "" to disable diagnostic settings without reading remote state.
  EOT
  default     = null

  validation {
    condition = (
      var.log_analytics_workspace_id == null ||
      var.log_analytics_workspace_id == "" ||
      can(regex(
        "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$",
        var.log_analytics_workspace_id
      ))
    )
    error_message = "log_analytics_workspace_id must be a valid Log Analytics workspace resource ID, an empty string, or null."
  }
}

variable "tfstate_rg" {
  type        = string
  description = "Resource group name of the Terraform remote state storage account. Required when reading monitoring or connectivity outputs via remote state."
  default     = ""
}

variable "tfstate_sa" {
  type        = string
  description = "Storage account name holding the Terraform remote state. Required when reading monitoring or connectivity outputs via remote state."
  default     = ""
}

# ---------------------------------------------------------------------------
# Telemetry and tags
# ---------------------------------------------------------------------------

variable "enable_telemetry" {
  type        = bool
  description = "Set false to opt out of AVM module usage telemetry."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged with the module-standard tag set (managed_by, root_module, owner, environment). Caller-supplied tags take precedence on key conflicts."
  default     = {}
}
