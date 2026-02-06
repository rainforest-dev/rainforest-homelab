variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "homelab"
}

variable "cluster_name" {
  description = "Teleport cluster name"
  type        = string
  default     = "homelab"
}

variable "public_hostname" {
  description = "Public hostname for Teleport (e.g., teleport.example.com)"
  type        = string
}

variable "kubernetes_cluster_name" {
  description = "Name of the Kubernetes cluster to provide access to"
  type        = string
  default     = "docker-desktop"
}

variable "teleport_version" {
  description = "Teleport Helm chart version"
  type        = string
  default     = "15.4.22"  # Latest stable OSS version
}

variable "cpu_limit" {
  description = "CPU limit for Teleport containers"
  type        = string
  default     = "1000m"
}

variable "memory_limit" {
  description = "Memory limit for Teleport containers"
  type        = string
  default     = "1Gi"
}

variable "storage_size" {
  description = "Storage size for Teleport data"
  type        = string
  default     = "10Gi"
}

variable "use_external_storage" {
  description = "Use external storage for persistence"
  type        = bool
  default     = false
}

variable "external_storage_path" {
  description = "Path to external storage for Teleport data"
  type        = string
  default     = "/var/lib/teleport"
}

variable "github_client_id" {
  description = "GitHub OAuth client ID for SSO (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth client secret for SSO (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_github_organizations" {
  description = "List of GitHub organizations allowed to access Teleport"
  type        = list(string)
  default     = []
}

variable "postgres_host" {
  description = "PostgreSQL host for database access proxy (optional)"
  type        = string
  default     = ""
}

variable "postgres_port" {
  description = "PostgreSQL port for database access proxy"
  type        = string
  default     = "5432"
}
