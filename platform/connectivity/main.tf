# Read the central Log Analytics workspace ID from tf-platform-monitoring remote state.
# The data source is skipped when var.log_analytics_workspace_id is set (override mode),
# which is the path used in unit tests and in CI pipelines that read remote state externally.
data "terraform_remote_state" "monitoring" {
  count = var.log_analytics_workspace_id == null ? 1 : 0

  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_rg
    storage_account_name = var.tfstate_sa
    container_name       = "tfstate"
    key                  = "platform/monitoring.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

# The module does not create resource groups — create it here and pass
# azurerm_resource_group.hub.id to default_parent_id on the module.
resource "azurerm_resource_group" "hub" {
  provider = azurerm.connectivity

  name     = local.hub_rg_name
  location = var.location
  tags     = local.tags
}

module "connectivity" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.16.14"

  # Explicit provider pass-through — required because the module uses for_each
  # internally and the default provider resolution does not propagate aliases.
  providers = { azurerm = azurerm.connectivity }

  enable_telemetry = var.enable_telemetry
  tags             = local.tags

  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = var.enable_ddos
    }
  }

  hub_virtual_networks = {
    primary = {
      location          = var.location
      default_parent_id = azurerm_resource_group.hub.id

      enabled_resources = {
        firewall                              = true
        firewall_policy                       = true
        bastion                               = true
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false
        private_dns_zones                     = true
        private_dns_resolver                  = true
      }

      hub_virtual_network = {
        name                             = local.hub_vnet_name
        address_space                    = [var.hub_address_space]
        mesh_peering_enabled             = false
        routing_address_space            = [var.routing_address_space]
        route_table_firewall_enabled     = true
        route_table_user_subnets_enabled = true
        ddos_protection_plan_id          = null
        tags                             = local.tags

        # Only the resolver outbound endpoint subnet is declared here.
        # AzureFirewallSubnet (/26), AzureBastionSubnet (/26), and the inbound
        # resolver subnet (/28) are synthesised by the module from the respective
        # feature blocks' subnet_address_prefix inputs.
        subnets = {
          dns_resolver_out = {
            name             = "dns-resolver-out"
            address_prefixes = [local.subnet_cidrs.resolver_out]
            delegations = [{
              name = "Microsoft.Network.dnsResolvers"
              service_delegation = {
                name    = "Microsoft.Network/dnsResolvers"
                actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
              }
            }]
          }
        }
      }

      firewall = {
        sku_name = "AZFW_VNet"
        sku_tier = "Standard"

        subnet_address_prefix = local.subnet_cidrs.firewall

        # Management IP is only required for Basic SKU or forced tunnelling.
        # Setting false for Standard without forced tunnel avoids an extra PIP and /26.
        management_ip_enabled            = false
        management_subnet_address_prefix = null

        private_ip_ranges = ["IANAPrivateRanges"]
        zones             = ["1", "2", "3"]
        tags              = local.tags

        ip_configurations = {
          primary = {
            is_default = true
            name       = "ipconfig1"
            public_ip_config = {
              zones                = ["1", "2", "3"]
              sku_tier             = "Regional"
              ip_version           = "IPv4"
              ddos_protection_mode = "VirtualNetworkInherited"
            }
          }
        }
      }

      firewall_policy = {
        sku = "Standard"

        # "Alert" and "Deny" are both valid for Standard SKU.
        # Do NOT set intrusion_detection, tls_certificate, or explicit_proxy —
        # those are Premium-only; Azure returns HTTP 400 on a Standard policy PUT.
        threat_intelligence_mode = var.threat_intelligence_mode

        private_ip_ranges = ["IANAPrivateRanges"]

        dns = {
          proxy_enabled = true
          # Resolver inbound IP is static so this field is plan-time-known on
          # first apply — no two-pass apply required.
          servers = [local.resolver_inbound_ip]
        }

        # insights is null when no LAW ID is available; the attribute is optional
        # in the module and the block is safely omitted when null.
        insights = local.firewall_policy_insights
      }

      bastion = {
        sku                    = "Standard"
        subnet_address_prefix  = local.subnet_cidrs.bastion
        scale_units            = var.bastion_scale_units
        copy_paste_enabled     = true
        file_copy_enabled      = true
        ip_connect_enabled     = true
        tunneling_enabled      = true
        shareable_link_enabled = false
        kerberos_enabled       = false
        zones                  = ["1", "2", "3"]
        tags                   = local.tags

        bastion_public_ip = {
          allocation_method = "Static"
          sku               = "Standard"
          zones             = ["1", "2", "3"]
        }
      }

      private_dns_zones = {
        auto_registration_zone_enabled = true
        auto_registration_zone_name    = var.auto_registration_zone_name
        private_link_excluded_zones    = var.excluded_private_link_zones
        tags                           = local.tags

        # Hub VNet ID is constructed deterministically from plan-time-known values.
        # The module owns the VNet resource so there is no direct resource reference;
        # this avoids a circular dependency while being idempotent across re-applies.
        virtual_network_link_default_virtual_networks = {
          hub = {
            virtual_network_resource_id = "${azurerm_resource_group.hub.id}/providers/Microsoft.Network/virtualNetworks/${local.hub_vnet_name}"
          }
        }
      }

      private_dns_resolver = {
        # enabled must be set explicitly — the module default is false even when
        # enabled_resources.private_dns_resolver = true.
        enabled = true

        subnet_name                      = "dns-resolver-in"
        subnet_address_prefix            = local.subnet_cidrs.resolver_in
        default_inbound_endpoint_enabled = true

        # Static IP avoids the two-pass apply described above.
        ip_address = local.resolver_inbound_ip
        tags       = local.tags

        outbound_endpoints = {
          out = {
            subnet_name        = "dns-resolver-out"
            forwarding_ruleset = local.dns_outbound_forwarding_rulesets
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Diagnostic settings
# Created only when a Log Analytics workspace ID is available.
# Skipped on first-pass bootstrap if monitoring has not yet been deployed.
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "hub_vnet" {
  count = local.law_resource_id != "" ? 1 : 0

  provider = azurerm.connectivity

  name                       = "diag-${local.hub_vnet_name}"
  target_resource_id         = module.connectivity.virtual_network_resource_ids["primary"]
  log_analytics_workspace_id = local.law_resource_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = local.law_resource_id != "" ? 1 : 0

  provider = azurerm.connectivity

  name                       = "diag-${local.hub_vnet_name}-afw"
  target_resource_id         = module.connectivity.firewall_resource_ids["primary"]
  log_analytics_workspace_id = local.law_resource_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  count = local.law_resource_id != "" ? 1 : 0

  provider = azurerm.connectivity

  name                       = "diag-${local.hub_vnet_name}-bas"
  target_resource_id         = module.connectivity.bastion_resource_ids["primary"]
  log_analytics_workspace_id = local.law_resource_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
