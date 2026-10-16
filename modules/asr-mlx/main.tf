locals {
  module_dir  = abspath(path.module)
  state_dir   = pathexpand("~/Library/Application Support/asr-mlx")
  venv_dir    = "${local.state_dir}/venv"
  venv_python = "${local.venv_dir}/bin/python"
  plist_label = "tools.rainforest.asr-mlx"
  plist_path  = pathexpand("~/Library/LaunchAgents/${local.plist_label}.plist")
  config_path = "${local.state_dir}/llama-swap.yaml"
  log_dir     = pathexpand(var.log_dir)
}

resource "null_resource" "uv_sync" {
  triggers = {
    lock_hash  = filemd5("${local.module_dir}/uv.lock")
    venv_dir   = local.venv_dir
    model_repo = var.model_repo
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      test -x "${var.llama_swap_bin}" || { echo "asr-mlx: ${var.llama_swap_bin} missing; install it as in CLAUDE.md, 'Qwen3-ASR on the host'" >&2; exit 1; }
      UV_PROJECT_ENVIRONMENT="${local.venv_dir}" uv sync --frozen --project "${local.module_dir}"
      "${local.venv_python}" -c "from huggingface_hub import snapshot_download; snapshot_download('${var.model_repo}')"
      mkdir -p "${local.log_dir}"
    EOT
  }
}

resource "local_sensitive_file" "llama_swap_config" {
  filename        = local.config_path
  file_permission = "0600"
  content = templatefile("${path.module}/llama-swap.yaml.tftpl", {
    api_key    = var.api_key
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
    config_md5 = local_sensitive_file.llama_swap_config.content_md5
    venv       = null_resource.uv_sync.id
    plist_path = local.plist_path
    label      = local.plist_label
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      test -x "${local.venv_python}"
      launchctl bootout "gui/$(id -u)/${self.triggers.label}" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "${self.triggers.plist_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "launchctl bootout \"gui/$(id -u)/${self.triggers.label}\" 2>/dev/null || true"
  }
}
