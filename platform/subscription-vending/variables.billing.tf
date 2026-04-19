variable "billing_model" {
  description = "Subscription billing model: EA (Enterprise Agreement), MCA (Microsoft Customer Agreement), MPA (Microsoft Partner Agreement), or Existing (adopt an existing subscription)."
  type        = string
  validation {
    condition     = contains(["EA", "MCA", "MPA", "Existing"], var.billing_model)
    error_message = "billing_model must be one of: EA, MCA, MPA, Existing."
  }
}

variable "subscription_display_name" {
  description = "Display name for the new subscription (1–64 characters)."
  type        = string
  validation {
    condition     = length(var.subscription_display_name) >= 1 && length(var.subscription_display_name) <= 64
    error_message = "subscription_display_name must be between 1 and 64 characters."
  }
}

variable "subscription_workload" {
  description = "Subscription workload type: Production or DevTest."
  type        = string
  default     = "Production"
  validation {
    condition     = contains(["Production", "DevTest"], var.subscription_workload)
    error_message = "subscription_workload must be Production or DevTest."
  }
}

variable "subscription_id" {
  description = "Existing subscription ID. Required when billing_model = 'Existing'."
  type        = string
  default     = null
  validation {
    condition     = var.subscription_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID when provided."
  }
}

variable "billing_account_name" {
  description = "Billing account name (EA: enrollment number; MCA/MPA: billing account GUID)."
  type        = string
  default     = null
}

variable "billing_enrollment_account" {
  description = "EA enrollment account name. Required when billing_model = 'EA'."
  type        = string
  default     = null
}

variable "billing_profile_name" {
  description = "MCA billing profile name. Required when billing_model = 'MCA'."
  type        = string
  default     = null
}

variable "billing_invoice_section_name" {
  description = "MCA invoice section name. Required when billing_model = 'MCA'."
  type        = string
  default     = null
}

variable "billing_customer_name" {
  description = "MPA customer name. Required when billing_model = 'MPA'."
  type        = string
  default     = null
}
