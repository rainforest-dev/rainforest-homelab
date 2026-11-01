variable "ssh_host" {
  description = "SSH host of the Windows PC, as named in ~/.ssh/config"
  type        = string
}

variable "ollama_version" {
  description = "Ollama release to install"
  type        = string
}

variable "ollama_sha256" {
  description = "SHA-256 of OllamaSetup.exe for that release"
  type        = string
}

variable "ollama_model" {
  description = "Model pulled on the PC at install"
  type        = string
}

variable "whisper_model" {
  description = "Default faster-whisper model"
  type        = string
}

variable "comfyui_dir" {
  description = "ComfyUI install directory on the PC"
  type        = string
}
