variable "container_name" {
  description = "The name of the container"
  type        = string
  default     = "ExampleNginxContainer"
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_email" {
  type      = string
  sensitive = true
}
