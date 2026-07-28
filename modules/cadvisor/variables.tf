variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "cAdvisor Docker image version"
  type        = string
  default     = "v0.52.1"
}

variable "port" {
  description = "Host port to expose cAdvisor metrics on"
  type        = number
  default     = 8181
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
