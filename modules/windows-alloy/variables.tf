variable "ssh_host" {
  description = "SSH host of the Windows PC, as named in ~/.ssh/config"
  type        = string
}

variable "machine" {
  description = "Host name stamped as the machine label on every pushed metric and log"
  type        = string
}

variable "alloy_version" {
  description = "Grafana Alloy release to install"
  type        = string
}

variable "alloy_sha256" {
  description = "SHA-256 of alloy-installer-windows-amd64.exe for that release"
  type        = string
}

variable "prometheus_remote_write_url" {
  description = "Prometheus remote_write endpoint on RPi"
  type        = string
}

variable "loki_push_url" {
  description = "Loki push endpoint on RPi"
  type        = string
}

variable "comfyui_log_path" {
  description = "ComfyUI log file on the PC, with forward slashes"
  type        = string
}
