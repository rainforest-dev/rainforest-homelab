variable "cloudflare_api_key" {
  description = "The API key for Cloudflare integration."
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "The email address associated with the Cloudflare account."
  type        = string
  sensitive   = true
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
