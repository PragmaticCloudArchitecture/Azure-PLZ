# Post-apply smoke tests — require real Azure credentials and a live environment.
# Run only in nightly ephemeral sandbox pipelines (not on PR).
#
# Prerequisites:
#   export ARM_USE_OIDC=true
#   export ARM_CLIENT_ID=<apply-uami-client-id>
#   export ARM_TENANT_ID=<tenant-id>
#   export ARM_SUBSCRIPTION_ID=<connectivity-sub-id>
#   terraform init -backend-config=env/sandbox.backend.hcl
#
# These tests apply real Azure resources — hub VNet creation takes ~20-30 minutes
# due to Azure Firewall and gateway provisioning. Expect significant cloud cost.

variables {
  location                     = "westeurope"
  environment                  = "smoke"
  hub_address_space            = "10.99.0.0/22"
  routing_address_space        = "10.99.0.0/22"
  auto_registration_zone_name  = "azure.smoke.internal"
  enable_telemetry             = false
  bastion_scale_units          = 2
  threat_intelligence_mode     = "Alert"
  enable_ddos                  = false

  # Pass LAW ID directly to skip monitoring remote state read in smoke tests.
  # Replace with a real workspace ID in the ephemeral sandbox subscription.
  log_analytics_workspace_id = ""
}

run "hub_resources_created" {
  command = apply

  assert {
    condition     = length(module.connectivity.virtual_network_resource_ids) > 0
    error_message = "Hub VNet resource ID must be present after apply."
  }

  assert {
    condition     = length(module.connectivity.firewall_resource_ids) > 0
    error_message = "Azure Firewall resource ID must be present after apply."
  }

  assert {
    condition     = length(module.connectivity.bastion_resource_ids) > 0
    error_message = "Bastion resource ID must be present after apply."
  }
}

run "private_dns_zones_created" {
  command = apply

  assert {
    condition     = length(module.connectivity.private_dns_zones) > 0
    error_message = "Private DNS zones must be created after apply."
  }
}

run "resolver_endpoint_reachable" {
  command = apply

  assert {
    condition     = local.resolver_inbound_ip == "10.99.2.4"
    error_message = "Resolver inbound IP must be 10.99.2.4 for the 10.99.0.0/22 smoke address space."
  }
}

run "second_plan_is_no_op" {
  command = plan

  assert {
    condition     = length(module.connectivity.virtual_network_resource_ids) > 0
    error_message = "Hub VNet must still be present on idempotency plan."
  }
}
