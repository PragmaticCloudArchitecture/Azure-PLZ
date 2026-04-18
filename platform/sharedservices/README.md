# tf-platform-sharedservices

Central IT root module that publishes reusable platform services for consumption by app teams and downstream Terraform roots. This root sits at build order position 4, after `tf-platform-governance`, `tf-platform-connectivity`, and `tf-platform-monitoring`.

**Owner:** Central IT / Platform Engineering
**Build order:** 4 of 6 — deploy after tf-platform-governance, tf-platform-connectivity, and tf-platform-monitoring.

## What it deploys

| Resource | Details |
|---|---|
| Resource Group | `rg-plat-ss-{env}-{region}` in the shared services subscription |
| Key Vault | RBAC model, Standard or Premium SKU, purge protection enabled |
| Private Endpoint | Optional — placed in a PE subnet provided by the caller |
| Diagnostic settings | Key Vault audit events → central Log Analytics workspace |

**Not deployed by this root:** Private DNS zones (owned by tf-platform-connectivity), DNS zone VNet links (owned by tf-subscription-vending), Key Vault RBAC role assignments (managed separately to avoid coupling), PE subnet (must exist before apply — see Prerequisites).

## Module version

`Azure/avm-res-keyvault-vault/azurerm` pinned at **`= 0.9.1`**.

## Architecture

```
Shared Services Subscription
└── rg-plat-ss-{env}-{region}
    ├── kv-{prefix}-{environment}          Key Vault (RBAC, purge protection)
    │   └── pe-kv-{prefix}-{environment}   Private Endpoint (optional)
    │       └── DNS: privatelink.vaultcore.azure.net → connectivity zone
    └── diag-kv-{name}                     Diagnostic setting → LAW
```

## RBAC model

The Key Vault is always created with `enable_rbac_authorization = true`. Access is granted through Azure role assignments, not legacy access policies. Typical platform roles:

| Role | Who | Scope |
|---|---|---|
| Key Vault Administrator | Platform engineers | Key Vault resource |
| Key Vault Secrets Officer | Automation identities | Key Vault resource |
| Key Vault Secrets User | App managed identities | Secret or Key Vault |

Role assignments are **not** managed by this root. Create them in the caller or in tf-subscription-vending using the `keyvault_id` output.

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | `~> 1.12` |
| tf-platform-governance | Must be applied first; subscription placement in the correct MG |
| tf-platform-connectivity | Must be applied first for the `privatelink.vaultcore.azure.net` DNS zone ID |
| tf-platform-monitoring | Must be applied first for the Log Analytics workspace ID |
| PE subnet | A subnet with `Microsoft.Network/privateEndpointNetworkPolicies = Disabled` must exist in the hub or peered VNet before apply |
| RBAC | `Contributor` on the shared services subscription |
| OIDC | `ARM_USE_OIDC=true`, federated UAMI, no client secrets |

## Usage

### Minimal — no private endpoint, LAW passed directly

```hcl
module "sharedservices" {
  source = "./platform/sharedservices"

  sharedservices_subscription_id = "11111111-1111-1111-1111-111111111111"
  tenant_id                      = "22222222-2222-2222-2222-222222222222"
  client_id                      = "33333333-3333-3333-3333-333333333333"
  location                       = "westeurope"
  environment                    = "prod"
  prefix                         = "contoso"
  keyvault_name                  = "kv-contoso-prod-001"

  log_analytics_workspace_id = data.terraform_remote_state.monitoring.outputs.log_analytics_workspace_id
}
```

### Production — private endpoint, remote state for LAW and DNS zone

```hcl
module "sharedservices" {
  source = "./platform/sharedservices"

  sharedservices_subscription_id = var.sharedservices_subscription_id
  tenant_id                      = var.tenant_id
  client_id                      = var.client_id
  location                       = "westeurope"
  environment                    = "prod"
  prefix                         = "contoso"
  keyvault_name                  = "kv-contoso-prod-001"

  private_endpoint_subnet_id = azurerm_subnet.pe.id

  tfstate_rg = "rg-tfstate-prod"
  tfstate_sa = "sttfstateprod001"

  tags = {
    costcenter  = "CC-0100"
    landingzone = "platform-sharedservices"
  }
}
```

## Cross-root data flow

```
tf-platform-monitoring
  → log_analytics_workspace_id
      → azurerm_monitor_diagnostic_setting (Key Vault audit events)

tf-platform-connectivity
  → private_dns_zone_ids["privatelink.vaultcore.azure.net"]
      → module.keyvault.private_endpoints["vault"].private_dns_zone_resource_ids

tf-platform-sharedservices outputs
  → keyvault_id  → tf-subscription-vending (RBAC role assignments)
  → keyvault_id  → tf-app-workload (Key Vault reference policies)
  → keyvault_uri → app runtime configuration
```

Downstream roots consume outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "sharedservices" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "platform/sharedservices.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

locals {
  keyvault_id  = data.terraform_remote_state.sharedservices.outputs.keyvault_id
  keyvault_uri = data.terraform_remote_state.sharedservices.outputs.keyvault_uri
}
```

## Key Vault name uniqueness

Azure Key Vault names are globally unique within Azure. The computed default (`kv-{prefix}-{environment}`) is suitable only for testing — set `keyvault_name` explicitly in every production deployment to guarantee uniqueness and avoid collisions with other tenants.

After soft-delete, the name remains reserved for the duration of `keyvault_soft_delete_retention_days`. If a deployment fails with "vault already exists in deleted state", either restore the vault (`az keyvault recover`) or use a different name.

## Known limitations

- **Key Vault RBAC assignments**: Not managed by this root. Grant access in the caller or in tf-subscription-vending to avoid coupling shared infrastructure to per-workload identities.
- **Private endpoint subnet**: Must be created outside this root before apply. This root accepts the subnet resource ID rather than creating the subnet to avoid cross-subscription resource dependencies.
- **DNS zone group**: When `keyvault_private_dns_zone_id` is null and connectivity remote state is unavailable, the private endpoint is created without a DNS zone group. Name resolution will not work until a zone group is added or DNS is configured manually.
- **Purge protection and destroy**: When `keyvault_purge_protection_enabled = true`, `terraform destroy` will soft-delete the vault but cannot purge it. The name remains reserved until the retention period expires.

## Testing

```bash
# Unit tests (mocked providers, no Azure credentials required)
terraform test tests/plan.tftest.hcl

# Smoke tests (requires real credentials, live Azure, ~2-5 min)
terraform test tests/apply.tftest.hcl
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
