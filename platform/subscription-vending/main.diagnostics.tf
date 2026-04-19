resource "azapi_resource" "sub_diagnostic_setting" {
  count = local.law_resource_id != "" ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "diag-sub-activity-${var.environment}"
  parent_id = "/subscriptions/${module.vending.subscription_id}"

  body = {
    properties = {
      workspaceId = local.law_resource_id
      logs = [
        {
          category        = "Administrative"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "Security"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "ServiceHealth"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "Alert"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "Recommendation"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "Policy"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "Autoscale"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          category        = "ResourceHealth"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
      ]
    }
  }

  depends_on = [module.vending]
}
