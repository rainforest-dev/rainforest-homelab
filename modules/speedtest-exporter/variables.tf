variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "speedtest-exporter image version"
  type        = string
  default     = "v3.5.4"
}

variable "port" {
  description = "Port to expose metrics on"
  type        = number
  default     = 9798
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
