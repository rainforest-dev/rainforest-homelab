variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "external_port" {
  description = "Port the board serves on, inside the container and on the host's loopback; its local URL is http://127.0.0.1:<port>/api/board"
  type        = number
  default     = 4100
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 1Gi)"
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

variable "allow_hosts" {
  description = "Public hostnames the board and its inspector answer on behind the tunnel; whoever reaches them acts as the owner, so each must sit behind Cloudflare Access"
  type        = list(string)
  default     = []
}
