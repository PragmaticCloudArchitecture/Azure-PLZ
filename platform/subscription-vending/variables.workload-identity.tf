variable "create_workload_identity" {
  description = "Whether to create a user-assigned managed identity (UAMI) in the vended subscription for CI/CD workload identity federation."
  type        = bool
  default     = false
}

variable "workload_identity_name" {
  description = "Name for the workload UAMI. Defaults to 'uami-cicd-<subscription_display_name>' when create_workload_identity = true."
  type        = string
  default     = null
}

variable "workload_identity_federated_credentials" {
  description = "Federated credentials to configure on the workload UAMI for OIDC trust. When empty and github_organization/github_repository are set, a default GitHub Actions credential is auto-generated."
  type = map(object({
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
    issuer    = string
    subject   = string
  }))
  default = {}
}

variable "github_organization" {
  description = "GitHub organization name used to auto-generate a federated credential subject when workload_identity_federated_credentials is empty."
  type        = string
  default     = null
}

variable "github_repository" {
  description = "GitHub repository name (without org prefix) used to auto-generate a federated credential subject."
  type        = string
  default     = null
}

variable "github_environment" {
  description = "GitHub Actions environment name for the federated credential (e.g. 'production'). When null, the subject is scoped to refs/heads/main."
  type        = string
  default     = null
}

variable "create_entra_group" {
  description = "Whether to create an Entra ID security group for the workload team and assign it a role on the vended subscription."
  type        = bool
  default     = false
}

variable "entra_group_display_name" {
  description = "Display name for the Entra ID group. Defaults to 'grp-sub-<subscription_display_name>'."
  type        = string
  default     = null
}

variable "entra_group_owners" {
  description = "Object IDs of Entra ID users or service principals to set as group owners."
  type        = list(string)
  default     = []
}

variable "entra_group_role_definition_name" {
  description = "Azure built-in role to assign to the Entra group on the vended subscription."
  type        = string
  default     = "Contributor"
  validation {
    condition     = contains(["Owner", "Contributor", "Reader"], var.entra_group_role_definition_name)
    error_message = "entra_group_role_definition_name must be one of: Owner, Contributor, Reader."
  }
}
