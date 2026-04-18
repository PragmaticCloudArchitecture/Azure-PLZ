# Stable re-exports consumed by tf-subscription-vending, tf-app-workload, and
# tf-platform-monitoring. Names here are the downstream contract — module-internal
# renames do not cascade to consumers as long as these wrappers are maintained.

output "hub_vnet_ids" {
  description = "Map of hub key to hub VNet resource ID. Consumed by tf-subscription-vending for spoke peering."
  value       = module.connectivity.virtual_network_resource_ids
}

output "firewall_private_ips" {
  description = "Map of hub key to Azure Firewall private IP address. Used as the next-hop IP in spoke UDRs."
  value       = module.connectivity.firewall_private_ip_addresses
}

output "firewall_public_ip_addresses" {
  description = "Map of hub key to Azure Firewall public IP addresses."
  value       = module.connectivity.firewall_public_ip_addresses
}

output "firewall_resource_ids" {
  description = "Map of hub key to Azure Firewall resource ID."
  value       = module.connectivity.firewall_resource_ids
}

output "firewall_policy_ids" {
  description = "Map of hub key to Firewall Policy resource ID. Used by azurerm_firewall_policy_rule_collection_group resources in this or downstream roots."
  value       = module.connectivity.firewall_policy_ids
}

output "bastion_resource_ids" {
  description = "Map of hub key to Azure Bastion resource ID."
  value       = module.connectivity.bastion_resource_ids
}

output "bastion_public_ip_addresses" {
  description = "Map of hub key to Bastion public IP address."
  value       = module.connectivity.bastion_public_ip_addresses
}

output "dns_servers" {
  description = "Map of hub key to list of DNS server IP addresses configured on the hub VNet. Use this list when setting dns_servers on spoke VNets in tf-subscription-vending."
  value       = module.connectivity.dns_servers
}

output "dns_resolver_inbound_ip" {
  description = "Static private IP of the DNS Private Resolver inbound endpoint. Used as the DNS forwarder target for on-premises conditional forwarders pointing at Azure."
  value       = local.resolver_inbound_ip
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name to resource ID. Consumed by tf-app-workload for private_dns_zone_group on private endpoints, and by tf-subscription-vending for spoke VNet links."
  value       = { for z in module.connectivity.private_dns_zones : z.name => z.resource_id }
}

output "route_table_user_subnets_ids" {
  description = "Map of hub key to the user-subnet route table resource ID. Associate spoke subnets with this RT in tf-subscription-vending to enforce 0.0.0.0/0 → firewall routing."
  value       = { for k, v in module.connectivity.route_tables_user_subnets : k => v.resource_id }
}

output "route_table_firewall_ids" {
  description = "Map of hub key to the AzureFirewallSubnet route table resource ID."
  value       = { for k, v in module.connectivity.route_tables_firewall : k => v.resource_id }
}

output "ddos_protection_plan_id" {
  description = "Resource ID of the DDoS Network Protection Plan, or null when DDoS is disabled. Pass to spoke VNets via tf-subscription-vending when enable_ddos = true."
  value       = module.connectivity.ddos_protection_plan_id
}

output "hub_resource_group_id" {
  description = "Resource ID of the hub resource group. Used by downstream roots that need to place resources in the same group."
  value       = azurerm_resource_group.hub.id
}

output "hub_resource_group_name" {
  description = "Name of the hub resource group."
  value       = azurerm_resource_group.hub.name
}

output "hub_virtual_networks" {
  description = "Full hub_virtual_networks composite output from the connectivity module. Inspect this for nested attributes not covered by the named outputs above."
  value       = module.connectivity.hub_virtual_networks
}

output "private_link_private_dns_zone_virtual_network_link_moved_blocks" {
  description = "Emits moved {} block text needed when upgrading the module to a new minor version. Paste the output into moved.tf before re-planning."
  value       = try(module.connectivity.private_link_private_dns_zone_virtual_network_link_moved_blocks, "")
}
