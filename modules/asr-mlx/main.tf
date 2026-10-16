locals {
  module_dir  = abspath(path.module)
  venv_python = "${local.module_dir}/.venv/bin/python"
  plist_label = "tools.rainforest.asr-mlx"
  plist_path  = pathexpand("~/Library/LaunchAgents/${local.plist_label}.plist")
  config_path = pathexpand("~/Library/Application Support/asr-mlx/llama-swap.yaml")
  log_dir     = pathexpand(var.log_dir)
}

resource "null_resource" "uv_sync" {
  triggers = {
    lock_hash = filemd5("${local.module_dir}/uv.lock")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      test -x "${var.llama_swap_bin}" || { echo "asr-mlx: ${var.llama_swap_bin} missing; see modules/asr-mlx/README.md" >&2; exit 1; }
      uv sync --frozen --project "${local.module_dir}"
      mkdir -p "${local.log_dir}"
    EOT
  }
}

resource "local_file" "llama_swap_config" {
  filename = local.config_path
  content = templatefile("${path.module}/llama-swap.yaml.tftpl", {
    model_name = var.model_name
    model_repo = var.model_repo
    python     = local.venv_python
    ttl        = var.ttl_seconds
  })
}

resource "local_file" "plist" {
  filename = local.plist_path
  content = templatefile("${path.module}/launchd.plist.tftpl", {
    label      = local.plist_label
    llama_swap = var.llama_swap_bin
    config     = local.config_path
    port       = var.port
    log_dir    = local.log_dir
    home_dir   = pathexpand("~")
  })
}

resource "null_resource" "launchd" {
  triggers = {
    plist_md5  = local_file.plist.content_md5
    config_md5 = local_file.llama_swap_config.content_md5
    venv       = null_resource.uv_sync.id
    plist_path = local.plist_path
    label      = local.plist_label
  }

  provisioner "local-exec" {
    command = <<-EOT
      launchctl bootout "gui/$(id -u)/${self.triggers.label}" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "${self.triggers.plist_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "launchctl bootout \"gui/$(id -u)/${self.triggers.label}\" 2>/dev/null || true"
  }
}
