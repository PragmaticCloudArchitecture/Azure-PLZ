# Azure Platform Landing Zone — Step-by-Step Deployment Guide

This guide walks through deploying all platform root modules in the correct order. Each module builds on the outputs of the previous ones via `terraform_remote_state`.

## Build Order

| Step | Module | State Key | Status |
|------|--------|-----------|--------|
| 1 | `platform/governance` | `governance/alz.tfstate` | Implemented |
| 2 | `platform/monitoring` | `platform/monitoring.tfstate` | **Not yet implemented** — see Step 2 |
| 3 | `platform/connectivity` | `platform/connectivity.tfstate` | Implemented |
| 4 | `platform/sharedservices` | `platform/sharedservices.tfstate` | Implemented |
| 5 | `platform/subscription-vending` | `subvending/<env>/<name>.tfstate` | Implemented (factory) |

---

## Prerequisites

### Azure Subscriptions

You need the following subscriptions before deploying. Create them manually or via the EA/MCA portal before running any Terraform.

| Subscription | Purpose | Variable |
|---|---|---|
| Management | Policy UAMI, Terraform state storage, Log Analytics | `management_subscription_id` |
| Connectivity | Hub VNet, Firewall, Bastion, DNS zones | `connectivity_subscription_id` |
| Identity | Shared identity workloads (AD DS, etc.) | `identity_subscription_id` |
| Shared Services | Platform Key Vault | `sharedservices_subscription_id` |

### Required RBAC

| Role | Scope | Purpose |
|---|---|---|
| Owner | Tenant Root Management Group | Governance: create MG hierarchy, assign policy |
| User Access Administrator | Tenant Root Management Group | Governance: assign roles to policy UAMIs (transient — revoke after apply) |
| Owner or Enrollment Account Owner | EA/MCA billing scope | Subscription Vending: create new subscriptions |
| Management Group Contributor | Target landing zone MG | Subscription Vending: subscription association |
| Storage Blob Data Contributor | Terraform state storage account | All modules: read/write state files |

### Required Tooling

```bash
# Minimum versions
terraform >= 1.12   # governance, connectivity, sharedservices
terraform >= 1.10   # subscription-vending
az >= 2.55          # Azure CLI (for bootstrap commands)
git >= 2.40
```

### Environment Variables (OIDC — no client secrets)

Set these in your shell or CI/CD environment before running any `terraform` command:

```bash
export ARM_TENANT_ID="<your-tenant-id>"
export ARM_CLIENT_ID="<your-workload-uami-client-id>"
export ARM_USE_OIDC=true
export ARM_USE_AZUREAD=true          # enables Entra ID auth for storage
# Do NOT set ARM_CLIENT_SECRET or ARM_SUBSCRIPTION_ID
```

---

## Step 0 — Bootstrap: Terraform State Backend

Before any Terraform runs, create the state storage account. Run once per environment.

```bash
LOCATION="westeurope"
ENV="prod"
MGMT_SUB="<management-subscription-id>"

az account set --subscription "$MGMT_SUB"

# Resource group
az group create \
  --name "rg-tfstate-${ENV}" \
  --location "$LOCATION"

# Storage account (RA-GZRS, TLS 1.2+, Entra ID only)
az storage account create \
  --name "sttfstate${ENV}001" \
  --resource-group "rg-tfstate-${ENV}" \
  --location "$LOCATION" \
  --sku Standard_RAGZRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --default-action Allow   # tighten to Deny + PE in production

# State container
az storage container create \
  --name tfstate \
  --account-name "sttfstate${ENV}001" \
  --auth-mode login

# Grant the deployment identity Storage Blob Data Contributor
DEPLOYER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
SA_ID=$(az storage account show \
  --name "sttfstate${ENV}001" \
  --resource-group "rg-tfstate-${ENV}" \
  --query id -o tsv)

az role assignment create \
  --assignee "$DEPLOYER_OBJECT_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$SA_ID"
```

Create a shared backend config file for each environment (gitignored):

```bash
# env/prod.backend.hcl  (referenced by -backend-config in all init commands)
cat > env/prod.backend.hcl <<EOF
resource_group_name  = "rg-tfstate-prod"
storage_account_name = "sttfstateprod001"
container_name       = "tfstate"
EOF
```

---

## Step 1 — Governance (`platform/governance`)

Deploys the ALZ management group hierarchy, Azure Policy definitions, policy assignments, and policy managed identities.

### 1.1 — Configure variables

```bash
cp platform/governance/terraform.tfvars.example platform/governance/terraform.tfvars
# Edit terraform.tfvars with your tenant ID, subscription IDs, and ALZ library ref
```

Key variables to set:

| Variable | Example | Notes |
|---|---|---|
| `root_parent_management_group_id` | `<tenant-id>` | Tenant Root Group GUID |
| `management_subscription_id` | `<uuid>` | Management subscription |
| `connectivity_subscription_id` | `<uuid>` | Connectivity subscription |
| `identity_subscription_id` | `<uuid>` | Identity subscription |
| `location` | `westeurope` | Primary Azure region |
| `environment` | `prod` | Used in resource naming |

> **Note:** The governance module has its backend hardcoded in `platform/governance/backend.tf`. Edit that file with your actual storage account name before the first `init`.

### 1.2 — Init, plan, and apply

```bash
cd platform/governance

terraform init

terraform plan -out=governance.tfplan

# Review the plan — expect ~50+ policy objects and 5 management groups
terraform apply governance.tfplan
```

### 1.3 — Verify outputs

```bash
terraform output management_group_resource_ids
terraform output policy_assignment_identity_ids
```

> **Important:** After apply, grant Remediation permissions to the policy UAMIs if using DeployIfNotExists policies. The `policy_assignment_identity_ids` output gives the principal IDs.

---

## Step 2 — Monitoring (`platform/monitoring`)

> **Status: Not yet implemented.** The `platform/monitoring` module does not exist in this repository. All downstream modules accept `log_analytics_workspace_id` as a direct variable override, so you can either:
>
> **Option A — Deploy a LAW manually via Azure CLI (quickest):**
> ```bash
> az monitor log-analytics workspace create \
>   --resource-group "rg-management-prod" \
>   --workspace-name "law-mgmt-prod" \
>   --location westeurope \
>   --retention-time 90
>
> az monitor log-analytics workspace show \
>   --resource-group "rg-management-prod" \
>   --workspace-name "law-mgmt-prod" \
>   --query id -o tsv
> # Copy the resource ID — pass it as log_analytics_workspace_id in Steps 3-5
> ```
>
> **Option B — Wait for the tf-platform-monitoring module** to be built, then deploy it before proceeding to Step 3. Its state key will be `platform/monitoring.tfstate` and it will output `log_analytics_workspace_id`.

---

## Step 3 — Connectivity (`platform/connectivity`)

Deploys the hub VNet, Azure Firewall, Azure Bastion, DNS Private Resolver, and ~75 Private Link DNS zones.

### 3.1 — Create backend config (if not already done)

```bash
mkdir -p env
# env/prod.backend.hcl should exist from Step 0
```

### 3.2 — Configure variables

```bash
cp platform/connectivity/terraform.tfvars.example platform/connectivity/terraform.tfvars
```

Key variables:

| Variable | Example | Notes |
|---|---|---|
| `connectivity_subscription_id` | `<uuid>` | Hub VNet subscription |
| `tenant_id` | `<uuid>` | Entra ID tenant |
| `client_id` | `<uuid>` | OIDC UAMI client ID |
| `location` | `westeurope` | Hub region |
| `environment` | `prod` | Naming suffix |
| `hub_address_space` | `["10.0.0.0/22"]` | Must be /22 or larger |
| `log_analytics_workspace_id` | `<law-resource-id>` | From Step 2; omit to use remote state |
| `tfstate_rg` | `rg-tfstate-prod` | Only needed if using remote state for LAW |
| `tfstate_sa` | `sttfstateprod001` | Only needed if using remote state for LAW |

### 3.3 — Init, plan, and apply

```bash
cd platform/connectivity

terraform init \
  -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=platform/connectivity.tfstate"

terraform plan -out=connectivity.tfplan

# Review — expect hub VNet, Firewall, Bastion, DNS Resolver, ~75 DNS zones
terraform apply connectivity.tfplan
```

### 3.4 — Verify outputs

```bash
terraform output private_dns_zone_ids     # map of ~75 privatelink zones
terraform output firewall_private_ips     # hub firewall IP (used as UDR next-hop)
terraform output dns_resolver_inbound_ip  # static inbound resolver IP
```

> **Subnet CIDR layout** (default /22 base `10.0.0.0/22`):
> | Subnet | CIDR |
> |---|---|
> | AzureFirewallSubnet | /26 |
> | AzureBastionSubnet | /26 |
> | dns-resolver-inbound | /28 (static IP = .4) |
> | dns-resolver-outbound | /28 |

---

## Step 4 — Shared Services (`platform/sharedservices`)

Deploys the platform Key Vault (RBAC model, optional private endpoint).

### 4.1 — Pre-requisite: PE subnet

If using a private endpoint for the Key Vault, a PE subnet must exist in the hub or a peered VNet **before** apply. Create it now if needed:

```bash
az network vnet subnet create \
  --vnet-name "vnet-plat-conn-prod-westeurope" \
  --resource-group "rg-plat-conn-prod-westeurope" \
  --name "pe-subnet" \
  --address-prefixes "10.0.1.0/27" \
  --subscription "<connectivity-subscription-id>"

az network vnet subnet update \
  --vnet-name "vnet-plat-conn-prod-westeurope" \
  --resource-group "rg-plat-conn-prod-westeurope" \
  --name "pe-subnet" \
  --private-endpoint-network-policies Disabled \
  --subscription "<connectivity-subscription-id>"
```

### 4.2 — Configure variables

```bash
cp platform/sharedservices/terraform.tfvars.example platform/sharedservices/terraform.tfvars
```

Key variables:

| Variable | Example | Notes |
|---|---|---|
| `sharedservices_subscription_id` | `<uuid>` | Shared services subscription |
| `tenant_id` | `<uuid>` | Entra ID tenant |
| `client_id` | `<uuid>` | OIDC UAMI client ID |
| `location` | `westeurope` | Deployment region |
| `environment` | `prod` | Naming suffix |
| `prefix` | `contoso` | 2-8 chars, globally unique KV name prefix |
| `keyvault_name` | `kv-contoso-prod-001` | **Set explicitly** — computed default not production-safe |
| `private_endpoint_subnet_id` | `<subnet-resource-id>` | From 4.1; omit for no PE |
| `log_analytics_workspace_id` | `<law-resource-id>` | From Step 2; omit to use remote state |
| `tfstate_rg` | `rg-tfstate-prod` | For remote state reads |
| `tfstate_sa` | `sttfstateprod001` | For remote state reads |

### 4.3 — Init, plan, and apply

```bash
cd platform/sharedservices

terraform init \
  -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=platform/sharedservices.tfstate"

terraform plan -out=sharedservices.tfplan

# Review — expect 1 resource group, 1 Key Vault, optionally 1 PE + 1 diagnostic setting
terraform apply sharedservices.tfplan
```

### 4.4 — Verify outputs and grant access

```bash
terraform output keyvault_id    # resource ID for downstream modules
terraform output keyvault_uri   # https://kv-contoso-prod-001.vault.azure.net/

# Grant platform engineers Key Vault Administrator
az role assignment create \
  --assignee "<platform-engineer-object-id>" \
  --role "Key Vault Administrator" \
  --scope "$(terraform output -raw keyvault_id)"
```

> **Key Vault names are globally unique.** After soft-delete, the name is reserved for up to 90 days. If deploy fails with "vault already exists in deleted state": `az keyvault recover --name kv-contoso-prod-001` or use a different name.

---

## Step 5 — Subscription Vending (`platform/subscription-vending`)

Factory pattern — one `terraform init` + `apply` per vended subscription, each with its own state file.

### 5.1 — Create a variable file per subscription

```bash
# Create a directory to hold per-subscription tfvars
mkdir -p subscriptions/prod

cat > subscriptions/prod/my-app.tfvars <<'EOF'
tenant_id                            = "<tenant-id>"
platform_management_subscription_id = "<mgmt-sub-id>"
connectivity_subscription_id         = "<conn-sub-id>"
environment                          = "prod"
location                             = "westeurope"
tfstate_storage_account_name         = "sttfstateprod001"

# Billing -- choose ONE model
billing_model              = "EA"
billing_account_name       = "<ea-billing-account-number>"
billing_enrollment_account = "<ea-enrollment-account>"

# Subscription identity
subscription_display_name = "my-app-prod"
subscription_workload     = "Production"

# Management group placement
management_group_id = "contoso-landingzones-prod"

# Networking
create_virtual_network        = true
virtual_network_address_space = ["10.10.0.0/24"]
hub_peering_enabled           = true

# Workload identity (CI/CD UAMI with GitHub Actions OIDC)
create_workload_identity = true
github_organization      = "my-org"
github_repository        = "my-app"
github_environment       = "production"

# Entra group
create_entra_group               = true
entra_group_role_definition_name = "Contributor"

tags = {
  costcenter  = "CC-0200"
  application = "my-app"
}
EOF
```

**Billing model alternatives** — replace the billing block above with:

```hcl
# MCA
billing_model                = "MCA"
billing_account_name         = "<guid>"
billing_profile_name         = "<guid>"
billing_invoice_section_name = "<guid>"

# MPA
billing_model         = "MPA"
billing_account_name  = "<guid>"
billing_customer_name = "<guid>"

# Existing (adopt an already-created subscription)
billing_model   = "Existing"
subscription_id = "<existing-subscription-uuid>"
```

### 5.2 — Init with per-subscription backend key

```bash
cd platform/subscription-vending

terraform init \
  -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=subvending/prod/my-app.tfstate" \
  -reconfigure
```

> Each subscription gets its own state file. The `-reconfigure` flag is needed when switching between subscriptions in the same shell session.

### 5.3 — Plan and apply

```bash
terraform plan \
  -var-file=../../subscriptions/prod/my-app.tfvars \
  -out=my-app.tfplan

# Review -- expect: subscription creation/adoption, MG association,
# spoke VNet + peering, diagnostic setting, UAMI, Entra group
terraform apply my-app.tfplan
```

### 5.4 — Capture outputs for downstream use

```bash
terraform output subscription_id             # vended subscription GUID
terraform output virtual_network_id          # spoke VNet resource ID
terraform output workload_identity_client_id # set as ARM_CLIENT_ID in GitHub Actions
terraform output entra_group_object_id       # Entra group for team access
```

### 5.5 — Configure GitHub Actions for the vended subscription

In GitHub -> your app repo -> Settings -> Environments -> `production`:

```
ARM_TENANT_ID       = <tenant-id>
ARM_CLIENT_ID       = <workload_identity_client_id from Step 5.4>
ARM_USE_OIDC        = true
ARM_SUBSCRIPTION_ID = <subscription_id from Step 5.4>
```

### 5.6 — Vend additional subscriptions

Repeat Steps 5.1-5.4 with a new `.tfvars` file and a different state key:

```bash
terraform init \
  -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=subvending/prod/another-app.tfstate" \
  -reconfigure

terraform plan \
  -var-file=../../subscriptions/prod/another-app.tfvars \
  -out=another-app.tfplan

terraform apply another-app.tfplan
```

---

## Reading Outputs Across Modules

Any root can read outputs from a previously applied root:

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
  hub_vnet_id          = data.terraform_remote_state.connectivity.outputs.hub_virtual_networks["default"].id
  private_dns_zone_ids = data.terraform_remote_state.connectivity.outputs.private_dns_zone_ids
}
```

### State key reference

| Module | State key |
|---|---|
| Governance | `governance/alz.tfstate` |
| Monitoring | `platform/monitoring.tfstate` |
| Connectivity | `platform/connectivity.tfstate` |
| Shared Services | `platform/sharedservices.tfstate` |
| Subscription (per-sub) | `subvending/<env>/<subscription_display_name>.tfstate` |

---

## Day-2 Operations

### Re-applying a module after a change

```bash
cd platform/<module>
terraform init -backend-config=../../env/prod.backend.hcl -backend-config="key=<state-key>"
terraform plan -out=update.tfplan
terraform apply update.tfplan
```

### Upgrading a module version

1. Update the `version` pin in the module's `main.tf`
2. Run `terraform init -upgrade`
3. Check `moved.tf` for any block additions required by the module changelog
4. Run `terraform plan` -- review all changes before applying

### Running unit tests (no Azure credentials needed)

```bash
cd platform/governance
terraform test tests/unit/

cd platform/sharedservices
terraform test tests/plan.tftest.hcl

cd platform/subscription-vending
terraform test tests/plan.tftest.hcl
```

### Drift detection

```bash
for module in governance connectivity sharedservices; do
  echo "=== Checking $module ==="
  cd platform/$module
  terraform init -backend-config=../../env/prod.backend.hcl \
    -backend-config="key=platform/${module}.tfstate" -reconfigure -input=false
  terraform plan -detailed-exitcode -input=false
  cd ../..
done
# exit code 0 = no changes, 2 = drift detected, 1 = error
```

---

## Destroy Order

Destroy in **reverse build order** to avoid broken remote state references:

```bash
# 5. Subscription vending (per-subscription -- destroy each one separately)
cd platform/subscription-vending
terraform init -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=subvending/prod/my-app.tfstate" -reconfigure
terraform destroy -var-file=../../subscriptions/prod/my-app.tfvars

# 4. Shared services
cd platform/sharedservices
terraform init -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=platform/sharedservices.tfstate" -reconfigure
terraform destroy -var-file=terraform.tfvars

# 3. Connectivity
cd platform/connectivity
terraform init -backend-config=../../env/prod.backend.hcl \
  -backend-config="key=platform/connectivity.tfstate" -reconfigure
terraform destroy -var-file=terraform.tfvars

# 1. Governance (last -- MG hierarchy and policies)
cd platform/governance
terraform destroy -var-file=terraform.tfvars
```

> **Key Vault destroy warning:** When `keyvault_purge_protection_enabled = true`, `terraform destroy` soft-deletes the vault but cannot purge it. The name remains reserved for `keyvault_soft_delete_retention_days` (default 90). Either recover it (`az keyvault recover`) or choose a new name on the next deployment.
>
> **Subscription destroy warning:** Destroying a subscription alias (EA/MCA/MPA) disables the subscription for 90 days before permanent deletion. The `subscription_id` output remains valid and the subscription is still billable during this period.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Error: vault already exists in deleted state` | KV soft-delete active from prior destroy | `az keyvault recover --name <kv-name>` or change `keyvault_name` |
| `Error: subscription_id is required` | azurerm 4.x needs `subscription_id` at plan time | Do not declare `provider "azurerm" { alias = "vended" }` -- use `azapi_resource` with `parent_id` |
| `Error: stream idle timeout` | Single push/apply payload too large | Split into smaller batches; check provider version compatibility |
| `Error: precondition failed` on `module.vending` | Missing billing model fields | Supply all required variables for the chosen `billing_model` |
| `Error: Backend initialization required` | Switched subscription state key | Add `-reconfigure` to `terraform init` |
| Plan shows unexpected drift on governance | ALZ library auto-updated | Pin `alz_library_ref` to a specific tag in variables |
| Policy UAMI role assignments fail | Missing User Access Administrator at tenant root | Grant UAA transiently, apply, revoke |
| Firewall rule deployment fails | Rule collection groups not managed by this repo | Deploy firewall rules via a separate Terraform root or Azure Firewall Policy child resource |
