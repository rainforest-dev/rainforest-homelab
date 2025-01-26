variable "namespace" {
  description = "Namespace where the NFS client provisioner will be deployed."
  type        = string
  default     = "default"
}

variable "name" {
  description = "Name of the NFS client provisioner deployment."
  type        = string
}

variable "capacity" {
  description = "storage capacity for the NFS client provisioner deployment."
  type        = string
  default     = "10Gi"
}

variable "requests" {
  description = "storage requests for the NFS client provisioner deployment."
  type        = string
  default     = "5Gi"
}
