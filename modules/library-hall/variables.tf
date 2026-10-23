variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "homelab"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "image" {
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/library-hall:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\" (e.g. ghcr.io/rainforest-dev/library-hall:latest); a digest form (repo@sha256:...) or a tag-less reference is not accepted, the module resolves and pins the digest itself."
  }
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8087
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g. 256Mi, 1Gi); the server only renders a static page and gathers hall items"
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

variable "collection_urls" {
  description = "Each collection as the hall's server reaches it, base path included, keyed books, notebooks, rack and kb; the hall reads <url>/api/hall-items. An empty URL leaves that shelf off"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for name in keys(var.collection_urls) : contains(["books", "notebooks", "rack", "kb"], name)])
    error_message = "collection_urls keys must be books, notebooks, rack or kb."
  }
}

variable "vault_system_path" {
  description = "Host path to the vault's _system folder, mounted read-only so the hall reads Topic-Map.md; empty leaves every collection's topics as they are"
  type        = string
  default     = ""
}
