# tf-platform-governance

Central IT root module that establishes the tenant-wide Azure Landing Zone foundation: management group hierarchy, Azure Policy definitions and assignments, custom role definitions, and management-group-scoped RBAC.

**Owner:** Central IT / Platform Engineering
**Build order:** 1 of 6 — deploy this root before all others.

## Architecture

This root module is a thin composition layer over [`Azure/avm-ptn-alz/azurerm`](https://registry.terraform.io/modules/Azure/avm-ptn-alz/azurerm/latest) v0.19. The module uses the [`Azure/alz`](https://registry.terraform.io/providers/Azure/alz/latest) provider (data-only) to download ALZ Library archetypes at `terraform init` time and materialize them via AzAPI resources.

Default ALZ hierarchy deployed:

```
Tenant Root Group
└── alz  (intermediate root)
    ├── platform
    │   ├── management
    │   ├── connectivity
    │   └── identity
    ├── landingzones
    │   ├── corp
    │   └── online
    ├── sandboxes
    └── decommissioned
```

## Prerequisites

| Requirement | Detail |
|---|---|
| Terraform | >= 1.12, < 2.0 |
| CI identity | Owner at `/providers/Microsoft.Management/managementGroups/<tenantId>` |
| User Access Administrator | Required transiently on tenant root for policy UAMI role assignments |
| OIDC | Workload-identity federation via `ARM_USE_OIDC=true` — no client secrets |
| State backend | Azure Blob Storage with OIDC, RA-GZRS, CMK, and PE-only network access |

## Build order and cross-root data flow

```
tf-platform-governance  ──outputs──>  tf-platform-connectivity
                        ──outputs──>  tf-platform-monitoring
                        ──outputs──>  tf-subscription-vending
```

Downstream roots read governance outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "governance" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "governance/alz.tfstate"
    use_oidc             = true
  }
}

# Example consumption
locals {
  connectivity_mg_id         = data.terraform_remote_state.governance.outputs.management_group_resource_ids["connectivity"]
  policy_identity_principals = data.terraform_remote_state.governance.outputs.policy_assignment_identity_ids
}
```

## Usage

### Minimal (first bootstrap)

```hcl
module "governance" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "~> 0.19"

  location                     = "eastus"
  management_subscription_id   = "00000000-0000-0000-0000-000000000001"
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
  identity_subscription_id     = "00000000-0000-0000-0000-000000000003"
}
```

### With monitoring wired and policy overrides

```hcl
module "governance" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "~> 0.19"

  location                     = "eastus"
  management_subscription_id   = data.terraform_remote_state.subscriptions.outputs.management_id
  connectivity_subscription_id = data.terraform_remote_state.subscriptions.outputs.connectivity_id
  identity_subscription_id     = data.terraform_remote_state.subscriptions.outputs.identity_id

  law_resource_id                = data.terraform_remote_state.monitoring.outputs.log_analytics_workspace_id
  automation_account_resource_id = data.terraform_remote_state.monitoring.outputs.automation_account_id

  policy_assignments_dependencies      = [data.terraform_remote_state.monitoring.outputs.log_analytics_workspace_id]
  policy_role_assignments_dependencies = [data.terraform_remote_state.monitoring.outputs.log_analytics_workspace_id]

  policy_assignments_to_modify = {
    landingzones = {
      policy_assignments = {
        Enforce-GR-KeyVault = {
          enforcement_mode = "Default"
          parameters = {
            secretsValidityInDays = jsonencode({ value = 120 })
          }
        }
      }
    }
  }

  management_group_role_assignments = {
    platform_owners = {
      management_group_name      = "platform"
      role_definition_id_or_name = "Owner"
      principal_id               = var.platform_owners_group_id
      principal_type             = "Group"
    }
  }
}
```

## Known design decisions

- **`depends_on` is not supported** by `avm-ptn-alz`. Use `management_groups_dependencies`, `policy_assignments_dependencies`, and `policy_role_assignments_dependencies` instead.
- **All policy parameter values must be `jsonencode({ value = ... })`-wrapped.** The module enforces this contract at the AzAPI layer.
- **Pin `alz_library_ref` explicitly.** The ALZ Library is versioned independently of the module. Upgrade library and module as separate change events.
- **`role_assignment_name_use_random_uuid = true` is hardcoded.** This prevents deterministic-UUID collisions on role assignment re-create in production.
- **Management groups cannot be tagged in Azure.** There is intentionally no `tags` variable — Azure does not support tags on management group resources.

## Testing

```bash
# Unit tests (mocked providers, no Azure credentials needed)
terraform test tests/unit/defaults.tftest.hcl
terraform test tests/unit/validation.tftest.hcl

# Integration tests (requires Azure credentials and Owner at tenant root)
terraform test tests/integration/governance.tftest.hcl
```

## CI pipeline stages

1. Pre-commit: `fmt`, `validate`, `tflint`, `terraform-docs`
2. Static security: `tfsec`, `checkov`, `trivy config`
3. Unit tests: `terraform test tests/unit/*.tftest.hcl` (mocked)
4. Plan + artifact upload
5. Conftest/OPA policy gate on plan JSON
6. Manual approval gate
7. Apply via OIDC
8. Integration tests against ephemeral MG subtree
9. Scheduled drift detection (`plan -detailed-exitcode`, every 1–4 hours)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
