locals {
  remote_dir = "homelab-windows-alloy"
  files      = ["alloy.river", "gpu-metrics.ps1", "install.ps1"]
  sources    = join(" ", [for file in local.files : "'${abspath("${path.module}/${file}")}'"])
}

resource "null_resource" "alloy" {
  triggers = {
    files_hash     = sha256(join("", [for file in local.files : filesha256("${path.module}/${file}")]))
    alloy_version  = var.alloy_version
    alloy_sha256   = var.alloy_sha256
    prometheus_url = var.prometheus_remote_write_url
    loki_url       = var.loki_push_url
    machine        = var.machine
    comfyui_log    = var.comfyui_log_path
    ssh_host       = var.ssh_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ssh -o BatchMode=yes -o ConnectTimeout=10 '${var.ssh_host}' 'if not exist ${local.remote_dir} mkdir ${local.remote_dir}'
      scp -q -o BatchMode=yes ${local.sources} '${var.ssh_host}:${local.remote_dir}/'
      ssh -o BatchMode=yes '${var.ssh_host}' 'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${local.remote_dir}\install.ps1 -Version ${var.alloy_version} -Sha256 ${var.alloy_sha256} -PrometheusUrl ${var.prometheus_remote_write_url} -LokiUrl ${var.loki_push_url} -Machine ${var.machine} -ComfyuiLog ${var.comfyui_log_path}'
      ssh -o BatchMode=yes '${var.ssh_host}' 'rmdir /s /q ${local.remote_dir}'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o BatchMode=yes -o ConnectTimeout=10 '${self.triggers.ssh_host}' 'schtasks /Delete /TN HomelabGpuMetrics /F & "C:\Program Files\GrafanaLabs\Alloy\uninstall.exe" /S'
    EOT
  }
}
