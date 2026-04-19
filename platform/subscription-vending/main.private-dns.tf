# Eager DNS zone linking — bypasses DINE policy for small estates.
# Only active when link_all_dns_zones = true and a VNet is being created.
# The resource group is extracted from each zone's resource ID to avoid
# requiring a separate variable.

locals {
  dns_links_to_create = (
    var.link_all_dns_zones
    && var.create_virtual_network
    && length(var.virtual_network_address_space) > 0
  ) ? {
    for zone_name, zone_id in local.private_dns_zone_ids : zone_name => {
      rg_name        = regex("/resourceGroups/([^/]+)/", zone_id)[0]
      vnet_link_name = "vnetlink-${replace(lower(var.subscription_display_name), " ", "-")}-${replace(zone_name, ".", "-")}"
    }
  } : {}
}

resource "azurerm_private_dns_zone_virtual_network_link" "vended" {
  provider = azurerm.connectivity
  for_each = local.dns_links_to_create

  name                  = each.value.vnet_link_name
  resource_group_name   = each.value.rg_name
  private_dns_zone_name = each.key
  virtual_network_id    = module.vending.virtual_networks["default"].id
  registration_enabled  = false
  tags                  = local.tags

  depends_on = [module.vending]
}
