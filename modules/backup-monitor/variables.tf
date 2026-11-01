variable "namespace" {
  type    = string
  default = "homelab"
}

variable "schedule" {
  description = "Cron for the freshness check. 09:00 = well after the backups (02:00-03:30) and the T7 sync (03:45)."
  type        = string
  default     = "0 9 * * *"
}

variable "image" {
  description = "Small image with find + busybox wget. Pinned by digest."
  type        = string
  default     = "alpine@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b"
}

variable "max_age_minutes" {
  description = "Alert if a bucket's newest offsite file is older than this. 1560 = 26h, one daily cycle plus slack."
  type        = number
  default     = 1560
}

variable "buckets" {
  description = "Backup directories expected under t7_path"
  type        = list(string)
  default = [
    "minio-backup/velero",
    "minio-backup/pi5-docker-backup",
    "minio-backup/mac-docker-backup",
    "postgres-backups",
  ]
}

variable "t7_path" {
  description = "T7 directory that holds every backup"
  type        = string
}

variable "webhook_url" {
  description = "n8n webhook that files the alert into the Obsidian daily note"
  type        = string
  default     = "http://homelab-n8n.homelab.svc.cluster.local:5678/webhook/ha-events"
}
