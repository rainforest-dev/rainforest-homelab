locals {
  remote_dir = "homelab-windows-gpu-services"
  sources = {
    "install.ps1"    = abspath("${path.module}/install.ps1")
    "main.py"        = abspath("${path.module}/../whisper/app/main.py")
    "pyproject.toml" = abspath("${path.module}/../whisper/app/pyproject.toml")
    "uv.lock"        = abspath("${path.module}/../whisper/app/uv.lock")
  }
  source_args = join(" ", [for source in values(local.sources) : "'${source}'"])
}

resource "null_resource" "services" {
  triggers = {
    files_hash     = sha256(join("", [for source in values(local.sources) : filesha256(source)]))
    ollama_version = var.ollama_version
    ollama_sha256  = var.ollama_sha256
    ollama_model   = var.ollama_model
    whisper_model  = var.whisper_model
    comfyui_dir    = var.comfyui_dir
    ssh_host       = var.ssh_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ssh -o BatchMode=yes -o ConnectTimeout=10 '${var.ssh_host}' 'if not exist ${local.remote_dir} mkdir ${local.remote_dir}'
      scp -q -o BatchMode=yes ${local.source_args} '${var.ssh_host}:${local.remote_dir}/'
      ssh -o BatchMode=yes '${var.ssh_host}' 'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${local.remote_dir}\install.ps1 -OllamaVersion ${var.ollama_version} -OllamaSha256 ${var.ollama_sha256} -OllamaModel ${var.ollama_model} -WhisperModel ${var.whisper_model} -ComfyuiDir ${var.comfyui_dir}'
      ssh -o BatchMode=yes '${var.ssh_host}' 'rmdir /s /q ${local.remote_dir}'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o BatchMode=yes -o ConnectTimeout=10 '${self.triggers.ssh_host}' 'for %t in (Whisper Ollama ComfyUI) do (schtasks /End /TN %t & schtasks /Delete /TN %t /F) & netsh advfirewall firewall delete rule name="ComfyUI 8188 Private LAN" & netsh advfirewall firewall delete rule name="Ollama 11434 Private LAN" & netsh advfirewall firewall delete rule name="Whisper 8000 Private LAN"'
    EOT
  }
}
