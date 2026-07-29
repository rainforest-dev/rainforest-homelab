variable "namespace" {
  type    = string
  default = "homelab"
}
variable "schedule" {
  description = "Cron for the dump. 03:15 = before the docker-volume-backup at 03:30."
  type        = string
  default     = "15 3 * * *"
}
variable "postgres_image" {
  description = "Image with pg_dumpall (client >= server major). Runs as root to write the hostPath dir."
  type        = string
  default     = "postgres:16-alpine"
}
variable "dump_host_path" {
  description = "Host dir for gzipped dumps; also mounted read-only into the docker-volume-backup container"
  type        = string
}
variable "keep" {
  description = "Number of dumps to retain locally"
  type        = number
  default     = 7
}
variable "pg_secret_name" {
  type    = string
  default = "homelab-postgresql-auth"
}
variable "pg_secret_key" {
  type    = string
  default = "postgres-password"
}
