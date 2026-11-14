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
  description = "Locally built image of the Inside Out variant (e.g. personal-memories:inside-out); never pulled"
  type        = string
}

variable "external_port" {
  description = "Host port the review app listens on"
  type        = number
  default     = 3005
}

variable "bind_ip" {
  description = "Host address the published port binds to; 127.0.0.1 keeps it off the LAN"
  type        = string
  default     = "127.0.0.1"
}

variable "data_dir" {
  description = "Host path to the memories data directory, mounted read-only"
  type        = string
}

variable "photos_library_path" {
  description = "Host path to the macOS Photos library, mounted read-only"
  type        = string
}

variable "notes_dir" {
  description = "Host path to the day notes, mounted read-only so a review cannot change them"
  type        = string
}

variable "v2_dir" {
  description = "Host path for the variant's own writable data (orbs.json)"
  type        = string
}

variable "owner_names" {
  description = "Comma-separated author names that are the album's owner"
  type        = string
  default     = ""
}

variable "identities" {
  description = "email=personId pairs that map an Access email to a people.json id; set in terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "ollama_url" {
  description = "Ollama endpoint for search embeddings, as reached from inside the container"
  type        = string
  default     = "http://host.docker.internal:11434"
}

variable "memory_limit_mb" {
  description = "Memory limit for the app container in MiB"
  type        = number
  default     = 512
}

variable "hostname" {
  description = "Subdomain the review app is published on"
  type        = string
  default     = "memories-next"
}

variable "domain_suffix" {
  description = "Zone the hostname lives in"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the tunnel"
  type        = string
}

variable "allowed_emails" {
  description = "The only emails the Access policy admits; set in terraform.tfvars"
  type        = list(string)
  sensitive   = true
}

variable "cloudflared_version" {
  description = "cloudflared image tag"
  type        = string
}
