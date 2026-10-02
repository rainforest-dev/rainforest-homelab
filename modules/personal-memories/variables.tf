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
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/personal-memories:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\" (e.g. ghcr.io/rainforest-dev/personal-memories:latest); a digest form (repo@sha256:...) or a tag-less reference is not accepted, the module resolves and pins the digest itself."
  }
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 3004
}

variable "data_dir" {
  description = "Host path to the memories data directory (line/, slack/, photos/, timeline.json)"
  type        = string
}

variable "photos_library_path" {
  description = "Host path to the macOS Photos library that timeline.json media paths point into"
  type        = string
}

variable "notes_dir" {
  description = "Host path to the Obsidian vault folder for day notes; the only read-write mount"
  type        = string
}

variable "owner_names" {
  description = "Comma-separated author names that are the album's owner (their messages are indented)"
  type        = string
  default     = ""
}

variable "authors" {
  description = "Comma-separated email=Name pairs that map a Cloudflare Access email to the name shown on a 眉批"
  type        = string
  default     = ""
  sensitive   = true
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 512Mi)"
  type        = string
  default     = "512Mi"
}
