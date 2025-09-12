variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "cloudflare_team_name" {
  description = "Cloudflare Zero Trust team name"
  type        = string
}

variable "domain_suffix" {
  description = "Domain suffix for the OAuth worker"
  type        = string
}

variable "oauth_client_id" {
  description = "OAuth client ID from Cloudflare Access"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth client secret from Cloudflare Access"
  type        = string
  sensitive   = true
}