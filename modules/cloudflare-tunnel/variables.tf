variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "domain_suffix" {
  description = "Domain suffix for services"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with appropriate permissions"
  type        = string
  sensitive   = true
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for tunnel deployment"
  type        = string
  default     = "homelab"
}

variable "allowed_email_domains" {
  description = "List of email domains allowed to access services"
  type        = list(string)
  default     = []
}

variable "allowed_emails" {
  description = "List of specific email addresses allowed to access services"
  type        = list(string)
  default     = []
}

variable "service_token_ids" {
  description = "List of Cloudflare Access Service Token IDs for programmatic access"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID for Zero Trust identity provider"
  type        = string
  default     = ""
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret for Zero Trust identity provider"
  type        = string
  default     = ""
  sensitive   = true
}

variable "services" {
  description = "Map of services to expose through Cloudflare Tunnel"
  type = map(object({
    hostname     = string
    service_url  = string
    enable_auth  = bool
    type         = string
    internal       = optional(bool, false)
    allowed_emails = optional(list(string), [])
  }))
  default = {}
}

