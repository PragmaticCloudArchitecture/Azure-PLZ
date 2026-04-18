# ---------------------------------------------------------------------------
# Identity and authentication
# ---------------------------------------------------------------------------

variable "connectivity_subscription_id" {
  type        = string
  description = "Subscription ID of the connectivity platform subscription. All hub resources are deployed here."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.connectivity_subscription_id))
    error_message = "connectivity_subscription_id must be a valid lowercase UUID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID. Used in provider OIDC configuration."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid lowercase UUID."
  }
}

variable "client_id" {
  type        = string
  description = "Client ID of the User-Assigned Managed Identity (or App Registration) used by the CI runner for OIDC authentication."

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
  description = "Azure region where all hub resources are deployed. Example: 'westeurope', 'eastus'."
  default     = "westeurope"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "location must be a lowercase Azure region name with no spaces or hyphens (e.g., 'westeurope', 'eastus')."
  }
}

variable "environment" {
  type        = string
  description = "Short environment name used in resource naming (e.g., 'prod', 'nonprod', 'dev'). Lowercase letters, numbers, and hyphens only."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "environment must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

# ---------------------------------------------------------------------------
# Hub network addressing
# ---------------------------------------------------------------------------

variable "hub_address_space" {
  type        = string
  description = "CIDR block for the hub VNet. Must be /22 or larger to accommodate the firewall (/26), Bastion (/26), and resolver (/28 x2) subnets without overlap."
  default     = "10.0.0.0/22"

  validation {
    condition     = can(cidrhost(var.hub_address_space, 0)) && tonumber(split("/", var.hub_address_space)[1]) <= 22
    error_message = "hub_address_space must be a valid CIDR block with a prefix length of /22 or shorter (e.g., '10.0.0.0/22')."
  }
}

variable "routing_address_space" {
  type        = string
  description = "Aggregate CIDR advertised from the hub to spokes as the routing_address_space. Typically the entire RFC-1918 range that covers all spoke CIDRs."
  default     = "10.0.0.0/8"

  validation {
    condition     = can(cidrhost(var.routing_address_space, 0))
    error_message = "routing_address_space must be a valid CIDR block."
  }
}

# ---------------------------------------------------------------------------
# DDoS
# ---------------------------------------------------------------------------

variable "enable_ddos" {
  type        = bool
  description = "Set true to create an Azure DDoS Network Protection Plan and associate it with the hub VNet. Incurs significant additional cost — confirm budget approval before enabling."
  default     = false
}

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------

variable "threat_intelligence_mode" {
  type        = string
  description = "Threat intelligence mode for the Standard firewall policy. 'Alert' logs matched traffic; 'Deny' blocks it. Both are valid on Standard SKU."
  default     = "Alert"

  validation {
    condition     = contains(["Alert", "Deny", "Off"], var.threat_intelligence_mode)
    error_message = "threat_intelligence_mode must be one of: Alert, Deny, Off."
  }
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------

variable "bastion_scale_units" {
  type        = number
  description = "Number of scale units for Azure Bastion Standard. Valid range is 2–50. Each scale unit supports approximately 25 concurrent sessions."
  default     = 2

  validation {
    condition     = var.bastion_scale_units >= 2 && var.bastion_scale_units <= 50
    error_message = "bastion_scale_units must be between 2 and 50."
  }
}

# ---------------------------------------------------------------------------
# Private DNS zones
# ---------------------------------------------------------------------------

variable "auto_registration_zone_name" {
  type        = string
  description = "Name of the auto-registration DNS zone for VM hostnames (non-privatelink). Example: 'azure.contoso.internal'."
  default     = "azure.contoso.internal"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.auto_registration_zone_name))
    error_message = "auto_registration_zone_name must be a valid DNS zone name (lowercase, letters, numbers, hyphens, dots)."
  }
}

variable "excluded_private_link_zones" {
  type        = set(string)
  description = "Set of private DNS zone DNS names (or map keys from the module's default zone list) to exclude from creation. Useful when a zone is owned by another team or already exists."
  default     = []
}

# ---------------------------------------------------------------------------
# DNS forwarding rules (on-premises resolution via DNS Private Resolver)
# ---------------------------------------------------------------------------

variable "dns_forwarding_rules" {
  type = map(object({
    domain_name              = string
    destination_ip_addresses = map(string)
    enabled                  = optional(bool, true)
  }))
  description = <<-EOT
    DNS conditional forwarding rules attached to the resolver outbound endpoint.
    Keyed by rule name. Leave empty (default) for cloud-only environments with no
    on-premises DNS integration. Example:

    dns_forwarding_rules = {
      corp = {
        domain_name              = "corp.contoso.com."
        destination_ip_addresses = { primary = "10.250.0.53:53", secondary = "10.250.0.54:53" }
      }
    }
  EOT
  default     = {}
}

# ---------------------------------------------------------------------------
# Monitoring integration
# ---------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  type        = string
  description = <<-EOT
    Override: Resource ID of the central Log Analytics workspace from tf-platform-monitoring.
    When set, the monitoring remote state data source is skipped entirely (useful in tests
    and CI pipelines that read remote state externally and pass values as variables).
    When null (default), the workspace ID is read from the monitoring remote state.
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
  description = "Resource group name of the Terraform remote state storage account used to read tf-platform-monitoring outputs. Required when log_analytics_workspace_id is null."
  default     = ""
}

variable "tfstate_sa" {
  type        = string
  description = "Storage account name holding the Terraform remote state used to read tf-platform-monitoring outputs. Required when log_analytics_workspace_id is null."
  default     = ""
}

# ---------------------------------------------------------------------------
# Telemetry and tags
# ---------------------------------------------------------------------------

variable "enable_telemetry" {
  type        = bool
  description = "Set false to opt out of Microsoft usage telemetry. The modtm provider must remain in required_providers regardless — remove it only if you also fork the module."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged with the module-standard tag set (managed_by, root_module, owner, environment). Caller-supplied tags take precedence on key conflicts."
  default     = {}
}
