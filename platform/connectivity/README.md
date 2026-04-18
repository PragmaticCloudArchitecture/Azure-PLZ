# tf-platform-connectivity

Central IT root module that builds and owns the hub network and all shared connectivity services for the Azure Landing Zone. This root sits at build order position 2, after `tf-platform-governance` and after `tf-platform-monitoring` (which provides the Log Analytics workspace ID).

**Owner:** Central IT / Platform Engineering
**Build order:** 2 of 6 — deploy after tf-platform-governance and tf-platform-monitoring.

## What it deploys

| Resource | Details |
|---|---|
| Hub VNet | Single-region, address space from `var.hub_address_space` |
| Azure Firewall Standard | Zones 1/2/3, `AZFW_VNet` SKU, Standard policy, no management IP |
| Azure Bastion Standard | Zones 1/2/3, scale_units configurable, Standard features enabled |
| ~75 Private Link DNS zones | Auto-created by `avm-ptn-network-private-link-private-dns-zones` v0.23.1 |
| Auto-registration DNS zone | VM hostname auto-registration zone (non-privatelink) |
| DNS Private Resolver | Inbound + outbound endpoints; static inbound IP for deterministic firewall policy |
| Route tables | Firewall RT (attached to AzureFirewallSubnet) + user-subnet RT (0.0.0.0/0 → AzFW) |
| Diagnostic settings | Hub VNet, Firewall, Bastion → central Log Analytics workspace |

**Not deployed by this root:** Resource groups for spoke workloads, NSGs on AzureBastionSubnet (manage separately if required by your control framework), firewall rule collection groups (create in root using `firewall_policy_ids` output), spoke VNet peerings and DNS zone links (created by tf-subscription-vending per spoke).

## Module version

Pinned at `Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm` **`= 0.16.14`** (not `~> 0.16`). Minor-version bumps require reading the `private_link_private_dns_zone_virtual_network_link_moved_blocks` output and populating `moved.tf` — see [Upgrading the module](#upgrading-the-module).

## Architecture

```
Connectivity Subscription
└── rg-plat-conn-{env}-{region}
    ├── vnet-plat-conn-{env}-{region}   /22 hub VNet
    │   ├── AzureFirewallSubnet          /26  (synthesised by module)
    │   ├── AzureBastionSubnet           /26  (synthesised by module)
    │   ├── dns-resolver-in              /28  (synthesised by module)
    │   └── dns-resolver-out             /28  (declared in subnets map)
    ├── Azure Firewall Standard (zones 1/2/3)
    ├── Firewall Policy Standard
    ├── Azure Bastion Standard (zones 1/2/3)
    ├── ~75 privatelink.*.azure.com DNS zones
    ├── {auto_registration_zone_name} DNS zone
    ├── DNS Private Resolver
    │   ├── Inbound endpoint  (static IP: cidrhost(resolver_in_subnet, 4))
    │   └── Outbound endpoint (forwarding ruleset from var.dns_forwarding_rules)
    ├── Route table: rt-hub-fw-*   (AzureFirewallSubnet)
    └── Route table: rt-hub-std-*  (spoke subnets — 0.0.0.0/0 → AzFW private IP)
```

## CIDR layout (default /22 base `10.0.0.0/22`)

| Subnet | CIDR | Azure minimum | Purpose |
|---|---|---|---|
| AzureFirewallSubnet | `10.0.0.0/26` | /26 | Azure Firewall |
| AzureBastionSubnet | `10.0.1.0/26` | /26 | Azure Bastion |
| dns-resolver-in | `10.0.2.0/28` | /28 | DNS Resolver inbound |
| dns-resolver-out | `10.0.2.16/28` | /28 | DNS Resolver outbound |

Resolver inbound static IP: `10.0.2.4` (`cidrhost(.../28, 4)`).

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | `~> 1.12` |
| tf-platform-governance | Must be applied first; MG hierarchy required for correct resource placement |
| tf-platform-monitoring | Must be applied first; LAW ID fed into firewall policy insights and diagnostic settings |
| RBAC on connectivity subscription | `Contributor` (or `Network Contributor` + `Private DNS Zone Contributor` + `DNS Resolver Contributor` + resource-group create) |
| OIDC | `ARM_USE_OIDC=true`, federated UAMI, no client secrets |

## Usage

### Minimal — pass LAW ID directly

```hcl
module "connectivity" {
  source = "./platform/connectivity"

  connectivity_subscription_id = "11111111-1111-1111-1111-111111111111"
  tenant_id                    = "22222222-2222-2222-2222-222222222222"
  client_id                    = "33333333-3333-3333-3333-333333333333"
  location                     = "westeurope"
  environment                  = "prod"

  log_analytics_workspace_id = data.terraform_remote_state.monitoring.outputs.log_analytics_workspace_id
}
```

### Production — read LAW from monitoring remote state

```hcl
module "connectivity" {
  source = "./platform/connectivity"

  connectivity_subscription_id = var.connectivity_subscription_id
  tenant_id                    = var.tenant_id
  client_id                    = var.client_id
  location                     = "westeurope"
  environment                  = "prod"
  hub_address_space            = "10.0.0.0/22"
  routing_address_space        = "10.0.0.0/8"

  tfstate_rg = "rg-tfstate-prod"
  tfstate_sa = "sttfstateprod001"

  dns_forwarding_rules = {
    corp = {
      domain_name              = "corp.contoso.com."
      destination_ip_addresses = { primary = "10.250.0.53:53", secondary = "10.250.0.54:53" }
    }
  }

  tags = {
    costcenter  = "CC-0100"
    landingzone = "platform-connectivity"
  }
}
```

## Cross-root data flow

```
tf-platform-monitoring
  → log_analytics_workspace_id
      → firewall_policy.insights.default_log_analytics_workspace_id
      → azurerm_monitor_diagnostic_setting (hub VNet, Firewall, Bastion)

tf-platform-connectivity outputs
  → hub_vnet_ids               → tf-subscription-vending (peering target)
  → firewall_private_ips       → tf-subscription-vending (UDR next-hop)
  → route_table_user_subnets_ids → tf-subscription-vending (spoke subnet association)
  → private_dns_zone_ids       → tf-app-workload (private_dns_zone_group)
  → dns_servers                → tf-subscription-vending (spoke VNet DNS config)
  → firewall_policy_ids        → (root) azurerm_firewall_policy_rule_collection_group
```

Downstream roots consume outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "connectivity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "platform/connectivity.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

locals {
  hub_vnet_id          = data.terraform_remote_state.connectivity.outputs.hub_vnet_ids["primary"]
  firewall_private_ip  = data.terraform_remote_state.connectivity.outputs.firewall_private_ips["primary"]
  user_rt_id           = data.terraform_remote_state.connectivity.outputs.route_table_user_subnets_ids["primary"]
  private_dns_zone_ids = data.terraform_remote_state.connectivity.outputs.private_dns_zone_ids
}
```

## Firewall rule collection groups

The module does not manage rule collection groups — create them in this root referencing the firewall policy output:

```hcl
resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  provider           = azurerm.connectivity
  name               = "rcg-baseline"
  firewall_policy_id = module.connectivity.firewall_policy_ids["primary"]
  priority           = 100

  network_rule_collection {
    name     = "allow-azure-platform"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-azure-monitor"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }
  }
}
```

## Upgrading the module

Before bumping the pinned version in `main.tf`:

1. Update `version = "0.16.14"` to the target version
2. Run `terraform init -upgrade`
3. Run `terraform plan` and check for DNS zone VNet link replacements
4. Run `terraform output -raw private_link_private_dns_zone_virtual_network_link_moved_blocks`
5. Paste the output into `moved.tf`
6. Run `terraform plan` again — verify zero resource replacements
7. Run `terraform apply`

## Known limitations

- **Bastion SKU**: Only `Basic` and `Standard` are available. Premium (session recording) requires an `azapi_resource` outside this module.
- **Firewall rule collection groups**: Not managed by the module. Create in root using `firewall_policy_ids` output.
- **Cross-subscription DNS zone VNet links**: Do not create these from this root. Let `tf-subscription-vending` register each spoke via its own per-subscription identity to avoid the 1000-link ceiling and cross-sub RBAC complexity.
- **DDoS Plan association**: Enabling `var.enable_ddos = true` requires `Microsoft.Network/ddosProtectionPlans/join/action` on the plan resource for any identity associating a VNet — ensure spoke-vending identity has this right.

## Testing

```bash
# Unit tests (mocked providers, no Azure credentials required)
terraform test tests/plan.tftest.hcl

# Smoke tests (requires real credentials, live Azure, ~20-30 min)
terraform test tests/apply.tftest.hcl
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
