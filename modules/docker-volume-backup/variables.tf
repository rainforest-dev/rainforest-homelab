variable "image_version" {
  description = "offen/docker-volume-backup image tag"
  type        = string
  default     = "v2.43.0"
}

variable "backup_schedule" {
  description = "Cron for the backup run. 03:30 = after the Pi (03:00) and the pg_dump CronJob (03:15)."
  type        = string
  default     = "30 3 * * *"
}

variable "retention_days" {
  description = "Prune archives older than this many days"
  type        = number
  default     = 14
}

variable "minio_bucket" {
  description = "MinIO bucket for Mac backups (pre-created by the minio module)"
  type        = string
  default     = "mac-docker-backup"
}

variable "minio_endpoint" {
  description = "MinIO S3 endpoint reachable from a Mac Docker container"
  type        = string
  default     = "host.docker.internal:9000"
}

variable "minio_access_key" {
  type      = string
  sensitive = true
}

variable "minio_secret_key" {
  type      = string
  sensitive = true
}

variable "postgres_dump_host_path" {
  description = "Host dir where the pg_dumpall CronJob writes; mounted read-only and shipped with the volumes"
  type        = string
}
