variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana MCP server image version"
  type        = string
  default     = "0.5.0"
}

variable "grafana_url" {
  description = "Grafana URL (internal LAN address)"
  type        = string
  default     = "http://raspberrypi-5.local:30080"
}

variable "grafana_api_key" {
  description = "Grafana service account API key (read-only)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mcp_port" {
  description = "Port for the MCP SSE server"
  type        = number
  default     = 8765
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
