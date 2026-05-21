variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy image version"
  type        = string
  default     = "v1.8.2"
}

variable "prometheus_remote_write_url" {
  description = "RPi Prometheus remote_write endpoint"
  type        = string
  default     = "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "loki_push_url" {
  description = "RPi Loki push endpoint"
  type        = string
  default     = "http://raspberrypi-5.local:30100/loki/api/v1/push"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
