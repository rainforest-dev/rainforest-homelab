variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

variable "tailscale_ip" {
  description = "Tailscale IP address of this machine"
  type        = string
}

variable "cpu_limit" {
  description = "CPU limit for CoreDNS container"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for CoreDNS container"
  type        = string
  default     = "512Mi"
}