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
  description = "Full Docker image reference (e.g. ghcr.io/rainforest-dev/personal-notebook:latest)"
  type        = string

  validation {
    condition     = can(regex("^[^@]+:[^:/@]+$", var.image))
    error_message = "image must be \"repo:tag\" (e.g. ghcr.io/rainforest-dev/personal-notebook:latest); a digest form (repo@sha256:...) or a tag-less reference is not accepted, the module resolves and pins the digest itself."
  }
}

variable "external_port" {
  description = "Host port to expose the app on"
  type        = number
  default     = 8086
}

variable "node_env" {
  description = "NODE_ENV value passed to the container"
  type        = string
  default     = "production"
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
  description = "Host address the published port binds to; 127.0.0.1 keeps it off the LAN while cloudflared and personal-calibre still reach it through host.docker.internal"
  type        = string
  default     = "127.0.0.1"
}

variable "mcp_secret" {
  description = "Shared secret personal-calibre sends as x-notebook-gateway when it forwards the notebook MCP tools; the app answers 404 on /notebooks/mcp without it"
  type        = string
  sensitive   = true
}

variable "inbox_secret" {
  description = "Shared secret n8n sends as x-inbox-secret to POST /notebooks/api/inbox/bujo; empty disables the route"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ollama_url" {
  description = "Ollama endpoint for page search embeddings and OCR, as reached from inside the container"
  type        = string
  default     = "http://host.docker.internal:11434"
}

variable "embed_model" {
  description = "Ollama embedding model; empty keeps the app's default"
  type        = string
  default     = ""
}

variable "ocr_model" {
  description = "Ollama vision model that transcribes notebook pages; empty turns OCR off"
  type        = string
  default     = ""
}

variable "import_volume" {
  description = "personal-calibre's app-data volume, mounted read-only so the first start can copy its notebooks; empty skips the import"
  type        = string
  default     = ""
}
