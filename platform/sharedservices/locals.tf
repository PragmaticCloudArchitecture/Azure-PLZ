locals {
  name_prefix = "plat-ss-${var.environment}"
  ss_rg_name  = "rg-${local.name_prefix}-${var.location}"

  # Key Vault name: operator-supplied or computed from prefix + environment.
  # Azure Key Vault names must be 3-24 chars, alphanumeric+hyphens, globally unique.
  # The computed default is suitable for testing; production deployments must override
  # keyvault_name to guarantee global uniqueness.
  kv_name = coalesce(var.keyvault_name, "kv-${var.prefix}-${var.environment}")

  # Private endpoint is enabled when the operator provides a subnet resource ID.
  pe_enabled = var.private_endpoint_subnet_id != null

  # LAW resource ID resolution priority:
  #   1. var.log_analytics_workspace_id (explicit override; skips remote state read)
  #   2. tf-platform-monitoring remote state output
  #   3. Empty string (diagnostic setting is then skipped)
  _monitoring_law_id = one(data.terraform_remote_state.monitoring[*].outputs.log_analytics_workspace_id)

  law_resource_id = (
    var.log_analytics_workspace_id != null && var.log_analytics_workspace_id != ""
    ? var.log_analytics_workspace_id
    : (local._monitoring_law_id != null ? local._monitoring_law_id : "")
  )

  # Key Vault private DNS zone ID resolution priority:
  #   1. var.keyvault_private_dns_zone_id (explicit override)
  #   2. tf-platform-connectivity remote state output (privatelink.vaultcore.azure.net)
  #   3. null (private endpoint created without DNS zone group — requires manual DNS)
  _connectivity_kv_dns_zone_id = try(
    one(data.terraform_remote_state.connectivity[*].outputs.private_dns_zone_ids)["privatelink.vaultcore.azure.net"],
    null
  )

  kv_private_dns_zone_id = (
    var.keyvault_private_dns_zone_id != null
    ? var.keyvault_private_dns_zone_id
    : local._connectivity_kv_dns_zone_id
  )

  base_tags = {
    managed_by  = "terraform"
    root_module = "tf-platform-sharedservices"
    owner       = "central-it"
    environment = var.environment
  }
  tags = merge(local.base_tags, var.tags)
}
