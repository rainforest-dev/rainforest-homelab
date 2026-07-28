locals {
  module_dir  = abspath(path.module)
  server_dir  = "${local.module_dir}/server"
  venv_dir    = "${local.module_dir}/.venv"
  venv_python = "${local.module_dir}/.venv/bin/python"
  plist_label = "tools.rainforest.comfyui"
  plist_path  = pathexpand("~/Library/LaunchAgents/${local.plist_label}.plist")
  log_dir     = pathexpand(var.log_dir)
}

# Install Python deps + clone ComfyUI-GGUF custom node via uv
resource "null_resource" "uv_setup" {
  triggers = {
    requirements_hash = filemd5("${local.server_dir}/requirements.txt")
    python_version    = var.python_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Create (or recreate) the virtual environment
      uv venv --python ${var.python_version} "${local.venv_dir}"

      # Install all ComfyUI dependencies
      uv pip install --python "${local.venv_python}" \
        -r "${local.server_dir}/requirements.txt"

      # Clone ComfyUI-GGUF custom node if missing (needed for .gguf model files)
      if [ ! -d "${local.server_dir}/custom_nodes/ComfyUI-GGUF/.git" ]; then
        git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git \
          "${local.server_dir}/custom_nodes/ComfyUI-GGUF"
      fi
      uv pip install --python "${local.venv_python}" "gguf>=0.13.0"

      # Ensure log directory exists before launchd starts writing
      mkdir -p "${local.log_dir}"

      echo "ComfyUI setup complete"
    EOT
  }
}

# Apply local patches to the vendored ComfyUI. The patches live here (tracked),
# NOT as uncommitted edits inside the submodule, so the submodule stays clean and
# the fix survives a `git submodule update`. Idempotent: skips if already applied.
resource "null_resource" "apply_patches" {
  triggers = {
    patch = filesha256("${local.module_dir}/patches/darwin27-psutil-compat.patch")
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      cd "${local.server_dir}"
      P="${local.module_dir}/patches/darwin27-psutil-compat.patch"
      if git apply --check "$P" 2>/dev/null; then
        git apply "$P" && echo "comfyui: applied darwin27-psutil-compat.patch"
      elif git apply --reverse --check "$P" 2>/dev/null; then
        echo "comfyui: darwin27-psutil-compat.patch already applied"
      else
        echo "comfyui: WARNING darwin27-psutil-compat.patch does not apply cleanly (ComfyUI upstream changed?)" >&2
        exit 1
      fi
    BASH
  }

  depends_on = [null_resource.uv_setup]
}

# Write the launchd plist to ~/Library/LaunchAgents/
resource "local_file" "plist" {
  filename = local.plist_path
  content = templatefile("${path.module}/launchd.plist.tftpl", {
    label        = local.plist_label
    python       = local.venv_python
    server_dir   = local.server_dir
    port         = var.port
    model_config = pathexpand(var.model_paths_config)
    log_dir      = local.log_dir
    home_dir     = pathexpand("~")
    extra_args   = var.extra_args
  })

  depends_on = [null_resource.uv_setup, null_resource.apply_patches]
}

# Load the launchd service; reload when plist content changes
resource "null_resource" "launchd" {
  triggers = {
    plist_md5  = local_file.plist.content_md5
    plist_path = local.plist_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      launchctl unload "${self.triggers.plist_path}" 2>/dev/null || true
      launchctl load "${self.triggers.plist_path}"
      echo "ComfyUI launchd service loaded on port ${var.port}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      launchctl unload "${self.triggers.plist_path}" 2>/dev/null || true
      echo "ComfyUI launchd service stopped"
    EOT
  }

  depends_on = [local_file.plist]
}
