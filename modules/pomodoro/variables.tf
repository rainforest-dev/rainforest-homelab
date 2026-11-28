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

variable "image" {
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/bambii-focus:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\"; the module resolves and pins the digest itself."
  }
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8790
}

variable "public_origin" {
  description = "The app's public origin, used for the CSP and as the sync origin"
  type        = string
  default     = "https://pomodoro.rainforest.tools"
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 1Gi)"
  type        = string
  default     = "256Mi"
}

variable "docker_host" {
  description = "Docker daemon the provider manages; the pre-replace pull targets the same daemon"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "bind_ip" {
  description = "Host address the published port binds to; 127.0.0.1 keeps it off the LAN while cloudflared still reaches it through host.docker.internal"
  type        = string
  default     = "127.0.0.1"
}

variable "vapid_public_key" {
  description = "Web Push VAPID public key; empty turns push off. Generate a pair with `pnpm --filter @bambii/sync-server vapid` in bambii-focus"
  type        = string
  default     = ""
}

variable "vapid_private_key" {
  description = "Web Push VAPID private key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vapid_subject" {
  description = "Web Push VAPID subject (a URL or mailto:)"
  type        = string
  default     = "https://pomodoro.rainforest.tools"
}
