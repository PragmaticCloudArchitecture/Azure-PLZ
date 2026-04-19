variable "create_virtual_network" {
  description = "Whether to create a VNet in the vended subscription and peer it to the hub."
  type        = bool
  default     = true
}

variable "virtual_network_address_space" {
  description = "CIDR address space(s) for the vended subscription VNet. A non-empty list is required when create_virtual_network = true."
  type        = list(string)
  default     = []
}

variable "connectivity_hub_virtual_network_id" {
  description = "Resource ID of the hub VNet for spoke peering. If null, read from tf-platform-connectivity remote state."
  type        = string
  default     = null
  validation {
    condition = var.connectivity_hub_virtual_network_id == null || can(
      regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$",
      var.connectivity_hub_virtual_network_id)
    )
    error_message = "connectivity_hub_virtual_network_id must be a valid VNet resource ID."
  }
}

variable "private_dns_zone_ids" {
  description = "Map of DNS zone name → resource ID for private DNS zone VNet linking. If empty, read from tf-platform-connectivity remote state."
  type        = map(string)
  default     = {}
}

variable "link_all_dns_zones" {
  description = "When true, eagerly link all private_dns_zone_ids to the vended VNet via azurerm.connectivity. Default false lets Azure Policy (DINE) handle zone linking."
  type        = bool
  default     = false
}

variable "hub_peering_enabled" {
  description = "Enable VNet peering from the vended spoke to the hub VNet."
  type        = bool
  default     = true
}

variable "hub_peering_use_remote_gateways" {
  description = "Allow the vended spoke to use the hub VPN/ExpressRoute gateways."
  type        = bool
  default     = false
}

variable "hub_peering_allow_forwarded_traffic" {
  description = "Allow forwarded (non-hub-originated) traffic through the hub→spoke peering."
  type        = bool
  default     = true
}
