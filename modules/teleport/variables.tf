variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
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
  default     = "15.4.22"
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

variable "bootstrap_admin_user" {
  description = "Automatically create an initial admin user if the cluster has none (still requires opening the printed invite URL once to set a password/passkey)"
  type        = bool
  default     = true
}

variable "admin_username" {
  description = "Username for the auto-bootstrapped initial admin user"
  type        = string
  default     = "admin"
}

variable "admin_roles" {
  description = "Comma-separated roles for the auto-bootstrapped admin user"
  type        = string
  default     = "editor,access"
}

variable "admin_logins" {
  description = "Comma-separated OS logins for the auto-bootstrapped admin user"
  type        = string
  default     = "root"
}
