locals {
  name_prefix   = "plat-conn-${var.environment}"
  hub_rg_name   = "rg-${local.name_prefix}-${var.location}"
  hub_vnet_name = "vnet-${local.name_prefix}-${var.location}"

  # Deterministic CIDR layout computed from var.hub_address_space.
  # With the default /22 base (1024 IPs) these produce:
  #   firewall     = cidrsubnet(/22, +4, idx 0)  → /26  (e.g. 10.0.0.0/26)
  #   bastion      = cidrsubnet(/22, +4, idx 4)  → /26  (e.g. 10.0.1.0/26)
  #   resolver_in  = cidrsubnet(/22, +6, idx 32) → /28  (e.g. 10.0.2.0/28)
  #   resolver_out = cidrsubnet(/22, +6, idx 33) → /28  (e.g. 10.0.2.16/28)
  # All meet Azure minimums: AzFW /26, Bastion /26, resolver /28.
  subnet_cidrs = {
    firewall     = cidrsubnet(var.hub_address_space, 4, 0)
    bastion      = cidrsubnet(var.hub_address_space, 4, 4)
    resolver_in  = cidrsubnet(var.hub_address_space, 6, 32)
    resolver_out = cidrsubnet(var.hub_address_space, 6, 33)
  }

  # Static inbound resolver IP — avoids the chicken-and-egg between the firewall
  # policy DNS servers list and the resolver endpoint's dynamically allocated IP.
  # cidrhost(.../28, 4) skips the three Azure-reserved IPs (.0-.3).
  resolver_inbound_ip = cidrhost(local.subnet_cidrs.resolver_in, 4)

  # LAW resource ID resolution priority:
  #   1. var.log_analytics_workspace_id (explicit override; skips remote state read)
  #   2. tf-platform-monitoring remote state output
  #   3. Empty string (diagnostic settings and firewall insights are then skipped)
  _monitoring_law_id = one(data.terraform_remote_state.monitoring[*].outputs.log_analytics_workspace_id)

  law_resource_id = (
    var.log_analytics_workspace_id != null && var.log_analytics_workspace_id != ""
    ? var.log_analytics_workspace_id
    : (local._monitoring_law_id != null ? local._monitoring_law_id : "")
  )

  # Firewall policy insights — only emitted when a LAW ID is available to avoid
  # a Standard policy PUT that references an empty workspace ID.
  firewall_policy_insights = local.law_resource_id != "" ? {
    enabled                            = true
    default_log_analytics_workspace_id = local.law_resource_id
    retention_in_days                  = 30
  } : null

  # DNS outbound forwarding rulesets — built from var.dns_forwarding_rules.
  # When the map is empty, no forwarding ruleset resources are created; the
  # outbound endpoint still exists for future use or Azure DNS pass-through.
  dns_outbound_forwarding_rulesets = length(var.dns_forwarding_rules) > 0 ? {
    onprem = {
      name                                        = "frs-${local.name_prefix}"
      link_with_outbound_endpoint_virtual_network = true
      rules = {
        for k, v in var.dns_forwarding_rules : k => {
          domain_name              = v.domain_name
          destination_ip_addresses = v.destination_ip_addresses
          enabled                  = v.enabled
        }
      }
    }
  } : {}

  base_tags = {
    managed_by  = "terraform"
    root_module = "tf-platform-connectivity"
    owner       = "central-it"
    environment = var.environment
  }
  tags = merge(local.base_tags, var.tags)
}
