resource "azurerm_resource_group" "sharedservices" {
  provider = azurerm.sharedservices

  name     = local.ss_rg_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Shared Key Vault
# RBAC authorisation model — do not use legacy access policies.
# Private endpoint is optional; set var.private_endpoint_subnet_id to enable.
# ---------------------------------------------------------------------------

module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "= 0.9.1"

  providers = { azurerm = azurerm.sharedservices }

  name                = local.kv_name
  resource_group_name = azurerm_resource_group.sharedservices.name
  location            = var.location
  tenant_id           = var.tenant_id

  sku_name = var.keyvault_sku

  # RBAC model — required for least-privilege secret access and Entra PIM integration.
  enable_rbac_authorization = true

  # Purge protection prevents accidental permanent deletion; recommended for production.
  purge_protection_enabled   = var.keyvault_purge_protection_enabled
  soft_delete_retention_days = var.keyvault_soft_delete_retention_days

  # Deny all public network access when a private endpoint is configured.
  # When no PE is requested the vault is internet-accessible (use ip_rules to restrict).
  public_network_access_enabled = local.pe_enabled ? false : var.keyvault_public_network_access_enabled

  network_acls = local.pe_enabled ? {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.keyvault_ip_rules
    virtual_network_subnet_ids = []
  } : null

  # Private endpoint — absent when var.private_endpoint_subnet_id is null.
  private_endpoints = local.pe_enabled ? {
    vault = {
      subnet_resource_id = var.private_endpoint_subnet_id

      # compact() drops null so the PE is created without a DNS zone group when
      # connectivity remote state is unavailable (no-network bootstrap scenario).
      private_dns_zone_resource_ids = compact([local.kv_private_dns_zone_id])

      tags = local.tags
    }
  } : {}

  enable_telemetry = var.enable_telemetry
  tags             = local.tags
}

# ---------------------------------------------------------------------------
# Diagnostic settings
# Created only when a Log Analytics workspace ID is available.
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  count = local.law_resource_id != "" ? 1 : 0

  provider = azurerm.sharedservices

  name                       = "diag-${local.kv_name}"
  target_resource_id         = module.keyvault.resource_id
  log_analytics_workspace_id = local.law_resource_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
