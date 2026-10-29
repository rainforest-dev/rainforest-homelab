variable "server_password" {
  description = "Password BlueBubbles Server requires on its API; Hermes sends it as BLUEBUBBLES_PASSWORD"
  type        = string
  sensitive   = true
}

variable "app_version" {
  description = "BlueBubbles Server release to install from GitHub"
  type        = string
  default     = "1.9.12"
}

variable "dmg_sha256" {
  description = "SHA-256 of BlueBubbles-<app_version>-arm64.dmg, from the GitHub release asset digest"
  type        = string
  default     = "923b562d2c945e7bb587576902f39af1456ec746b041090a397296e0786d5d43"
}

variable "port" {
  description = "Port BlueBubbles Server listens on (Settings > Connection)"
  type        = number
  default     = 1234
}

variable "app_dir" {
  description = "Directory the app is installed into"
  type        = string
  default     = "/Applications"
}
