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
