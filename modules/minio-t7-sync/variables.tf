variable "namespace" {
  type    = string
  default = "homelab"
}

variable "schedule" {
  description = "Cron for the sync. 03:45 = after the Pi (03:00) and Mac (03:30) backups have uploaded."
  type        = string
  default     = "45 3 * * *"
}

variable "mc_image" {
  description = "MinIO client image, pinned by digest for reproducibility."
  type        = string
  default     = "minio/mc@sha256:a7fe349ef4bd8521fb8497f55c6042871b2ae640607cf99d9bede5e9bdf11727"
}

variable "minio_url" {
  description = "In-cluster MinIO endpoint (no Cloudflare, no host networking)"
  type        = string
  default     = "http://homelab-minio.homelab.svc.cluster.local:9000"
}

variable "minio_secret_name" {
  type    = string
  default = "homelab-minio"
}

variable "buckets" {
  description = "Buckets to mirror. Listed explicitly because the mc image has no awk/grep to parse a discovered list."
  type        = list(string)
  default     = ["velero", "pi5-docker-backup", "mac-docker-backup"]
}

variable "t7_path" {
  description = "Destination on the Samsung T7. Synology Drive Client backs this folder up to the NAS."
  type        = string
}
