variable "port" {
  description = "Port the ComfyUI Python server listens on"
  type        = number
  default     = 8188
}

variable "model_paths_config" {
  description = "Path to extra_models_config.yaml (model search paths)"
  type        = string
  default     = "~/Library/Application Support/ComfyUI/extra_models_config.yaml"
}

variable "log_dir" {
  description = "Directory for ComfyUI stdout/stderr logs"
  type        = string
  default     = "~/Library/Logs/ComfyUI"
}

variable "python_version" {
  description = "Python version for the uv-managed virtual environment"
  type        = string
  default     = "3.12"
}

variable "extra_args" {
  description = "Extra CLI arguments passed to main.py (e.g. --force-fp16)"
  type        = list(string)
  default     = []
}
