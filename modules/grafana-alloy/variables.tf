variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
}

variable "prometheus_remote_write_url" {
  description = "Prometheus remote_write endpoint on RPi"
  type        = string
  default     = "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "loki_push_url" {
  description = "Loki push endpoint on RPi"
  type        = string
  default     = "http://raspberrypi-5.local:30100/loki/api/v1/push"
}

variable "kubeconfig_path" {
  description = "Absolute path to kubeconfig for K8s pod log discovery"
  type        = string
  default     = "/Users/rainforest/.kube/config"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
