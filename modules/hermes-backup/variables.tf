variable "backup_dir" {
  description = "Directory the zips go to; the job skips the run when it is missing (T7 unmounted)"
  type        = string
  default     = "/Volumes/Samsung T7 Touch/homelab-data/hermes-backups"
}

variable "hermes_bin" {
  description = "Hermes CLI"
  type        = string
  default     = "~/.local/bin/hermes"
}

variable "keep" {
  description = "Newest backups to keep; older hermes-backup-*.zip files are deleted"
  type        = number
  default     = 14
}

variable "hour" {
  description = "Hour of the nightly run"
  type        = number
  default     = 4
}

variable "minute" {
  description = "Minute of the nightly run"
  type        = number
  default     = 30
}
