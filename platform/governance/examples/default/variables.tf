variable "location" {
  type        = string
  description = "Azure region for the deployment."
  default     = "eastus"
}

variable "management_subscription_id" {
  type        = string
  description = "Subscription ID for the management platform subscription."
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Subscription ID for the connectivity platform subscription."
}

variable "identity_subscription_id" {
  type        = string
  description = "Subscription ID for the identity platform subscription."
}
