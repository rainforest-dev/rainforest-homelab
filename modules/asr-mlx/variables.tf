variable "api_key" {
  description = "Key llama-swap requires on every request; whisper sends it as a Bearer token"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Port llama-swap listens on (127.0.0.1 only)"
  type        = number
  default     = 9191
}

variable "model_name" {
  description = "Model name clients send; whisper's remote_models key"
  type        = string
  default     = "qwen3-asr"
}

variable "model_repo" {
  description = "Hugging Face repo mlx-audio loads for model_name"
  type        = string
  default     = "mlx-community/Qwen3-ASR-1.7B-8bit"
}

variable "ttl_seconds" {
  description = "Idle seconds before llama-swap stops the mlx-audio server and frees its memory"
  type        = number
  default     = 600
}

variable "llama_swap_bin" {
  description = "llama-swap binary (brew install from the mostlygeek/llama-swap tap)"
  type        = string
  default     = "/opt/homebrew/bin/llama-swap"
}

variable "log_dir" {
  description = "Directory for llama-swap and mlx-audio logs"
  type        = string
  default     = "~/Library/Logs/asr-mlx"
}
