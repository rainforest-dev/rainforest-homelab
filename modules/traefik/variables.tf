variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "homelab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "traefik_name" {
  description = "The name of the Traefik deployment."
  type        = string
  default     = "traefik"
}

variable "traefik_namespace" {
  description = "The namespace where Traefik will be deployed."
  type        = string
  default     = "traefik"
}

variable "domain_suffix" {
  description = "Domain suffix for services"
  type        = string
  default     = "localhost"
}

variable "enable_cloudflare" {
  description = "Enable Cloudflare DNS integration"
  type        = bool
  default     = false
}

variable "cloudflare_api_key" {
  description = "The API key for Cloudflare integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_email" {
  description = "The email address associated with the Cloudflare account."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cpu_limit" {
  description = "CPU limit for Traefik"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Traefik"
  type        = string
  default     = "512Mi"
}

variable "chart_repository" {
  description = "Helm chart repository name"
  type        = string
  default     = "traefik"
}
