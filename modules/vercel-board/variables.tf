variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "api_port" {
  description = "Port of the board API, inside the container and on the host's loopback; its local URL is http://127.0.0.1:<port>/api/board"
  type        = number
  default     = 4100
}

variable "memory_limit" {
  description = "Memory limit for the board container (e.g. 256Mi, 1Gi)"
  type        = string
  default     = "256Mi"
}

variable "board_user" {
  description = "OS user the board runs as inside the container; the board names its owner local:user:<board_user>"
  type        = string
  default     = "owner"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,31}$", var.board_user))
    error_message = "board_user must be a lowercase POSIX user name."
  }
}

variable "token_dir" {
  description = "Absolute host directory the board signs its owner token into, so vb on the host finds it (~/.config/board/local)"
  type        = string
}

variable "hostname" {
  description = "Subdomain the inspector is published on"
  type        = string
  default     = "board"
}

variable "domain_suffix" {
  description = "Cloudflare zone the hostname lives in"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the board's tunnel"
  type        = string
  sensitive   = true
}

variable "allowed_emails" {
  description = "Emails Access lets through; whoever passes acts as the board owner"
  type        = list(string)

  validation {
    condition     = length(var.allowed_emails) > 0
    error_message = "allowed_emails needs at least one address; the inspector acts as the owner for everyone Access lets in."
  }
}

variable "cloudflared_version" {
  description = "cloudflared image tag"
  type        = string
}
