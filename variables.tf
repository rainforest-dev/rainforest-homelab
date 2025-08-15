# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "homelab"
}

# Infrastructure Configuration
variable "docker_host" {
  description = "Docker daemon host (unix:///var/run/docker.sock for local)"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubernetes_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "docker-desktop"
}

variable "domain_suffix" {
  description = "Domain suffix for services"
  type        = string
  default     = "localhost"
}

# Storage Configuration
variable "docker_volume_root" {
  description = "Root path for Docker volumes"
  type        = string
  default     = "/var/lib/docker/volumes"
}

variable "enable_persistence" {
  description = "Enable persistent storage for services"
  type        = bool
  default     = true
}

# Cloudflare Configuration
variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read, Zone:Edit, Account:Read permissions"
  type        = string
  sensitive   = true
  default     = ""
}

# Feature Flags
variable "enable_traefik" {
  description = "Enable Traefik ingress controller"
  type        = bool
  default     = true
}

variable "enable_postgresql" {
  description = "Enable PostgreSQL database"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = false
}

variable "enable_coredns" {
  description = "Enable CoreDNS server for custom domains"
  type        = bool
  default     = false
}

variable "enable_cloudflare_tunnel" {
  description = "Enable Cloudflare Tunnel for secure external access"
  type        = bool
  default     = false
}

variable "tailscale_ip" {
  description = "Tailscale IP address of this machine"
  type        = string
  sensitive   = true
  default     = ""
}

# Resource Sizing
variable "default_cpu_limit" {
  description = "Default CPU limit for services"
  type        = string
  default     = "500m"
}

variable "default_memory_limit" {
  description = "Default memory limit for services"
  type        = string
  default     = "512Mi"
}

variable "default_storage_size" {
  description = "Default storage size for persistent volumes"
  type        = string
  default     = "10Gi"
}

# Zero Trust Configuration
variable "allowed_email_domains" {
  description = "List of email domains allowed to access services via Zero Trust"
  type        = list(string)
  default     = []
}

variable "allowed_emails" {
  description = "List of specific email addresses allowed to access services"
  type        = list(string)
  default     = []
}
