variable "namespace" {
  description = "Namespace cert-manager is installed into"
  type        = string
  default     = "cert-manager"
}

variable "chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.2"
}

variable "issuer_name" {
  description = "Name of the ClusterIssuer that other modules reference"
  type        = string
  default     = "letsencrypt-cloudflare"
}

variable "acme_email" {
  description = "Email Let's Encrypt sends expiry notices to"
  type        = string

  validation {
    condition     = var.acme_email != ""
    error_message = "Set acme_email in terraform.tfvars to enable Teleport direct access."
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit on the zone, used for DNS-01 challenges"
  type        = string
  sensitive   = true
}
