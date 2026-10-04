variable "runner_ref" {
  description = "rainforest-monorepo commit SHA the runner checks out"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.runner_ref))
    error_message = "runner_ref must be a full 40-character commit SHA, not a branch or tag."
  }
}

variable "repo_url" {
  description = "Clone URL of rainforest-monorepo"
  type        = string
  default     = "https://github.com/rainforest-dev/rainforest-monorepo.git"
}

variable "runner_dir" {
  description = "Dedicated checkout the job runs from; never the owner's working copy"
  type        = string
  default     = "~/.local/share/memories-runner"
}

variable "node_path" {
  description = "Node 24+ binary launchd starts; this exact binary needs Full Disk Access"
  type        = string
  default     = "/opt/homebrew/bin/node"
}

variable "data_dir" {
  description = "MEMORIES_DATA_DIR: the album's data root, the same path the container mounts"
  type        = string
}

variable "drop_dir" {
  description = "MEMORIES_DROP_DIR: iCloud folder LINE exports are dropped into; launchd watches it"
  type        = string
  default     = "~/Library/Mobile Documents/com~apple~CloudDocs/Memories Inbox"
}

variable "photos_library_path" {
  description = "MEMORIES_PHOTOS_LIBRARY: the Photos library osxphotos exports from"
  type        = string
}

variable "photos_from" {
  description = "MEMORIES_PHOTOS_FROM: first day of the nightly Photos export window (YYYY-MM-DD)"
  type        = string
  default     = "2025-05-01"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.photos_from))
    error_message = "photos_from must be YYYY-MM-DD."
  }
}

variable "ollama_url" {
  description = "MEMORIES_OLLAMA_URL: Ollama endpoint as reached from the host"
  type        = string
  default     = "http://localhost:11434"
}

variable "webhook_url" {
  description = "MEMORIES_IMPORT_WEBHOOK: n8n ha-events webhook, as reached from the host"
  type        = string
}

variable "schedule" {
  description = "Nightly run time, HH:MM local time"
  type        = string
  default     = "03:30"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.schedule))
    error_message = "schedule must be HH:MM in 24-hour time."
  }
}

variable "log_dir" {
  description = "Directory for the job's stdout/stderr logs"
  type        = string
  default     = "~/Library/Logs/memories-auto-import"
}
