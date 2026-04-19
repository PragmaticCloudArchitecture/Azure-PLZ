# tf-subscription-vending

Factory root module that vends Azure landing zone subscriptions using the AVM pattern module `Azure/avm-ptn-alz-sub-vending/azure`. This root sits at build order position 5, after `tf-platform-governance`, `tf-platform-connectivity`, `tf-platform-monitoring`, and `tf-platform-sharedservices`.

**Owner:** Central IT / Platform Engineering
**Build order:** 5 of 6 — deploy after tf-platform-governance, tf-platform-connectivity, tf-platform-monitoring, and tf-platform-sharedservices.

## What it deploys

| Resource | Details |
|---|---|
| Subscription | Created via EA/MCA/MPA billing scope or adopted from an existing subscription |
| MG association | Subscription placed into the target management group |
| VNet + peering | Spoke VNet peered to the hub VNet (optional) |
| Diagnostic setting | Subscription activity logs → central Log Analytics workspace (via AzAPI) |
| DNS zone links | Eager private DNS zone → spoke VNet links via `azurerm.connectivity` (optional, default: DINE) |
| UAMI | Workload managed identity with GitHub Actions OIDC federation (optional) |
| Entra group | Security group + role assignment on the vended subscription (optional) |

**Not deployed by this root:** Private DNS zones (tf-platform-connectivity), hub VNet (tf-platform-connectivity), Log Analytics workspace (tf-platform-monitoring), Key Vault (tf-platform-sharedservices).

## Module version

`Azure/avm-ptn-alz-sub-vending/azure` pinned at **`= 0.2.0`**.

## Architecture

```
Management subscription (pivot)
└── Terraform state: subvending/<env>/<subscription_name>.tfstate

Vended subscription
├── rg-networking-{env}
│   └── vnet-{name}-{env}              Spoke VNet
│       └── peering → hub VNet         (azurerm.connectivity side)
├── rg-identity-{env}
│   └── uami-cicd-{name}               Workload UAMI (optional)
│       └── federated credential        GitHub Actions OIDC
├── Microsoft.Insights/diagnosticSettings
│   └── diag-sub-activity-{env}        Activity logs → LAW
└── Microsoft.Authorization/roleAssignments
    └── Entra group → Contributor      (optional)
```

## Billing model

Set `billing_model` to one of `EA`, `MCA`, `MPA`, or `Existing`. The required companion variables differ per model:

| Model | Required variables |
|---|---|
| `EA` | `billing_account_name`, `billing_enrollment_account` |
| `MCA` | `billing_account_name`, `billing_profile_name`, `billing_invoice_section_name` |
| `MPA` | `billing_account_name`, `billing_customer_name` |
| `Existing` | `subscription_id` |

Validation `precondition` blocks on `module.vending` enforce these requirements at plan time.

## Provider design

| Provider | Subscription | Purpose |
|---|---|---|
| `azurerm` (default) | `platform_management_subscription_id` | Backend auth, cross-sub RBAC |
| `azurerm.connectivity` | `connectivity_subscription_id` | DNS zone VNet links |
| `azapi` | (none — set per resource via `parent_id`) | Subscription-scoped resources post-vending |
| `azuread` | (tenant-wide) | Entra group management |

**No `azurerm.vended` alias.** The vended subscription ID is known-after-apply for new subscriptions; azurerm 4.x requires `subscription_id` at plan time. All in-subscription resources (diagnostic settings, role assignments) use `azapi_resource` with `parent_id = "/subscriptions/${module.vending.subscription_id}"`.

## Factory pattern

Each vended subscription has its own state file. Supply the key at `terraform init`:

```bash
terraform init \
  -backend-config="key=subvending/prod/my-app.tfstate" \
  -backend-config="storage_account_name=sttfstateplatform"

terraform apply -var-file=subscriptions/prod/my-app.tfvars
```

## Cross-root data flow

```
tf-platform-connectivity
  → hub_virtual_network_id       → module.vending virtual_networks hub peering
  → private_dns_zone_ids         → azurerm_private_dns_zone_virtual_network_link

tf-platform-monitoring
  → log_analytics_workspace_id   → azapi_resource sub_diagnostic_setting

tf-platform-sharedservices
  → keyvault_id                  → available via output for caller use

tf-subscription-vending outputs
  → subscription_id              → app workload roots
  → virtual_network_id           → app workload subnet deployment
  → workload_identity_client_id  → GitHub Actions env var (ARM_CLIENT_ID)
```

Downstream roots consume outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "vending" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-platform"
    storage_account_name = "sttfstateplatform"
    container_name       = "tfstate"
    key                  = "subvending/prod/my-app.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

locals {
  subscription_id = data.terraform_remote_state.vending.outputs.subscription_id
  vnet_id         = data.terraform_remote_state.vending.outputs.virtual_network_id
}
```

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | `~> 1.10` |
| tf-platform-governance | MG hierarchy must exist before subscription placement |
| tf-platform-connectivity | Hub VNet must exist for spoke peering |
| tf-platform-monitoring | LAW must exist for activity log diagnostics |
| RBAC | `Owner` or `Enrollment Account Owner` on the billing scope; `Management Group Contributor` on the target MG |
| OIDC | `ARM_USE_OIDC=true`, federated UAMI, no client secrets |

## Usage

### Minimal — existing subscription, no VNet

```hcl
module "vending" {
  source = "./platform/subscription-vending"

  tenant_id                            = var.tenant_id
  platform_management_subscription_id = var.platform_management_subscription_id
  connectivity_subscription_id         = var.connectivity_subscription_id
  environment                          = "prod"
  location                             = "westeurope"
  billing_model                        = "Existing"
  subscription_id                      = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  subscription_display_name            = "my-app-prod"
  management_group_id                  = "contoso-landingzones-prod"
  create_virtual_network               = false
  tfstate_storage_account_name         = "sttfstateplatform"
}
```

### Full — EA billing, VNet, UAMI, Entra group

```hcl
module "vending" {
  source = "./platform/subscription-vending"

  tenant_id                            = var.tenant_id
  platform_management_subscription_id = var.platform_management_subscription_id
  connectivity_subscription_id         = var.connectivity_subscription_id
  environment                          = "prod"
  location                             = "westeurope"
  tfstate_storage_account_name         = "sttfstateplatform"

  billing_model              = "EA"
  billing_account_name       = "12345678"
  billing_enrollment_account = "987654321"

  subscription_display_name = "my-app-prod"
  subscription_workload     = "Production"
  management_group_id       = "contoso-landingzones-prod"

  create_virtual_network        = true
  virtual_network_address_space = ["10.10.0.0/24"]
  hub_peering_enabled           = true

  create_workload_identity = true
  github_organization      = "contoso"
  github_repository        = "my-app"
  github_environment       = "production"

  create_entra_group               = true
  entra_group_role_definition_name = "Contributor"

  tags = {
    costcenter  = "CC-0200"
    application = "my-app"
  }
}
```

## Known limitations

- **`azurerm.vended` alias**: Not used — the vended subscription ID is known-after-apply for new subscriptions, making azurerm 4.x provider configuration impossible at plan time. Use `azapi_resource` with `parent_id` for all in-subscription resources.
- **DINE policy vs eager DNS linking**: By default `link_all_dns_zones = false`; Azure Policy DINE assignments handle zone linking. Set `link_all_dns_zones = true` only for small estates where DINE is not deployed.
- **Budget**: The `budget_amount` and `budget_alert_emails` variables are declared but not yet wired to a budget resource. Add a `azurerm_consumption_budget_subscription` resource in a future iteration.
- **Destroy**: Destroying this root soft-deletes the subscription (MCA/EA). The subscription alias is removed but the subscription itself enters a 90-day disabled state before permanent deletion.

## Testing

```bash
# Unit tests (mocked providers, no Azure credentials required)
terraform test tests/plan.tftest.hcl

# Smoke tests (requires real credentials, live Azure, ~5-10 min)
terraform test tests/apply.tftest.hcl
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
