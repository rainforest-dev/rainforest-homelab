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
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/reading-room:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\" (e.g. ghcr.io/rainforest-dev/reading-room:latest); a digest form (repo@sha256:...) or a tag-less reference is not accepted, the module resolves and pins the digest itself."
  }
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8084
}

variable "vault_registry_path" {
  description = "Host path to the Obsidian vault folder containing RSS registry markdown files"
  type        = string
}

variable "kb_wiki_pages_path" {
  description = "Host path to the vault's notes/wiki/pages, mounted read-only at /kb/wiki; empty mounts nothing"
  type        = string
  default     = ""
}

variable "kb_readwise_path" {
  description = "Host path to the vault's readwise folder, mounted read-only at /kb/readwise; empty mounts nothing"
  type        = string
  default     = ""
}

variable "kb_redact_terms" {
  description = "Words that mark company content in /kb, passed as KB_REDACT_TERMS"
  type        = list(string)
  default     = ["angible"]
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 512Mi)"
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
