# Plan-only unit tests — no Azure credentials required.
# Run: terraform test tests/plan.tftest.hcl
#
# var.log_analytics_workspace_id is set to bypass the monitoring remote state
# data source (count = 0 path), so tfstate_rg/tfstate_sa are not contacted.

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000011"
  tenant_id                    = "00000000-0000-0000-0000-000000000001"
  client_id                    = "00000000-0000-0000-0000-000000000003"
  location                     = "westeurope"
  environment                  = "test"
  hub_address_space            = "10.0.0.0/22"
  routing_address_space        = "10.0.0.0/8"
  auto_registration_zone_name  = "azure.test.internal"

  # Bypass remote state read in tests
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management"
}

run "plan_succeeds_with_minimum_required_inputs" {
  command = plan
}

run "cidr_firewall_subnet_is_slash_26" {
  command = plan

  assert {
    condition     = local.subnet_cidrs.firewall == "10.0.0.0/26"
    error_message = "Firewall subnet should be 10.0.0.0/26 for a 10.0.0.0/22 base."
  }
}

run "cidr_bastion_subnet_is_slash_26" {
  command = plan

  assert {
    condition     = local.subnet_cidrs.bastion == "10.0.1.0/26"
    error_message = "Bastion subnet should be 10.0.1.0/26 for a 10.0.0.0/22 base."
  }
}

run "cidr_resolver_in_subnet_is_slash_28" {
  command = plan

  assert {
    condition     = local.subnet_cidrs.resolver_in == "10.0.2.0/28"
    error_message = "Resolver inbound subnet should be 10.0.2.0/28 for a 10.0.0.0/22 base."
  }
}

run "cidr_resolver_out_subnet_is_slash_28" {
  command = plan

  assert {
    condition     = local.subnet_cidrs.resolver_out == "10.0.2.16/28"
    error_message = "Resolver outbound subnet should be 10.0.2.16/28 for a 10.0.0.0/22 base."
  }
}

run "resolver_inbound_ip_is_fourth_host" {
  command = plan

  assert {
    condition     = local.resolver_inbound_ip == "10.0.2.4"
    error_message = "Resolver inbound IP should be 10.0.2.4 (fourth host in 10.0.2.0/28)."
  }
}

run "naming_convention_resource_group" {
  command = plan

  assert {
    condition     = local.hub_rg_name == "rg-plat-conn-test-westeurope"
    error_message = "Hub resource group name must follow the rg-plat-conn-{env}-{region} pattern."
  }
}

run "naming_convention_vnet" {
  command = plan

  assert {
    condition     = local.hub_vnet_name == "vnet-plat-conn-test-westeurope"
    error_message = "Hub VNet name must follow the vnet-plat-conn-{env}-{region} pattern."
  }
}

run "law_override_variable_is_used_when_provided" {
  command = plan

  assert {
    condition     = local.law_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000010/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-management"
    error_message = "law_resource_id local must reflect the override variable when it is set."
  }
}

run "law_empty_string_suppresses_insights" {
  command = plan

  variables {
    log_analytics_workspace_id = ""
  }

  assert {
    condition     = local.law_resource_id == ""
    error_message = "law_resource_id should be empty when override variable is an empty string."
  }

  assert {
    condition     = local.firewall_policy_insights == null
    error_message = "firewall_policy_insights should be null when no LAW ID is available."
  }
}

run "standard_tags_present" {
  command = plan

  assert {
    condition     = local.tags["managed_by"] == "terraform"
    error_message = "Tags must include managed_by=terraform."
  }

  assert {
    condition     = local.tags["root_module"] == "tf-platform-connectivity"
    error_message = "Tags must include root_module=tf-platform-connectivity."
  }

  assert {
    condition     = local.tags["environment"] == "test"
    error_message = "Tags must include environment matching var.environment."
  }
}

run "caller_tags_merged_over_base_tags" {
  command = plan

  variables {
    tags = { costcenter = "CC-0100", managed_by = "override" }
  }

  assert {
    condition     = local.tags["costcenter"] == "CC-0100"
    error_message = "Caller-supplied tags must be present after merge."
  }

  assert {
    condition     = local.tags["managed_by"] == "override"
    error_message = "Caller-supplied tags must take precedence over base tags on key conflicts."
  }
}

run "no_forwarding_rulesets_when_dns_rules_empty" {
  command = plan

  assert {
    condition     = local.dns_outbound_forwarding_rulesets == {}
    error_message = "dns_outbound_forwarding_rulesets must be empty when no dns_forwarding_rules are provided."
  }
}

run "forwarding_ruleset_created_when_rules_provided" {
  command = plan

  variables {
    dns_forwarding_rules = {
      corp = {
        domain_name              = "corp.contoso.com."
        destination_ip_addresses = { p = "10.250.0.53:53" }
      }
    }
  }

  assert {
    condition     = length(local.dns_outbound_forwarding_rulesets) > 0
    error_message = "dns_outbound_forwarding_rulesets must be non-empty when dns_forwarding_rules are provided."
  }
}
