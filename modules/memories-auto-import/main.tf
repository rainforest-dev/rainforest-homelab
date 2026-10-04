locals {
  plist_label = "tools.rainforest.memories-auto-import"
  plist_path  = pathexpand("~/Library/LaunchAgents/${local.plist_label}.plist")
  home_dir    = pathexpand("~")
  runner_dir  = pathexpand(var.runner_dir)
  log_dir     = pathexpand(var.log_dir)
  drop_dir    = pathexpand(var.drop_dir)
  script      = "${local.runner_dir}/apps/personal-memories/src/cli/auto-import.ts"
  schedule    = split(":", var.schedule)

  env = {
    HOME                    = local.home_dir
    PATH                    = "${local.home_dir}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    MEMORIES_DATA_DIR       = pathexpand(var.data_dir)
    MEMORIES_DROP_DIR       = local.drop_dir
    MEMORIES_PHOTOS_LIBRARY = pathexpand(var.photos_library_path)
    MEMORIES_PHOTOS_FROM    = var.photos_from
    MEMORIES_OLLAMA_URL     = var.ollama_url
    MEMORIES_IMPORT_WEBHOOK = var.webhook_url
  }
}

resource "null_resource" "runner" {
  triggers = {
    ref        = var.runner_ref
    repo_url   = var.repo_url
    runner_dir = local.runner_dir
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      REF  = self.triggers.ref
      REPO = self.triggers.repo_url
      DIR  = self.triggers.runner_dir
    }
    command = <<-EOT
      set -euo pipefail
      if [ ! -d "$DIR/.git" ]; then
        mkdir -p "$(dirname "$DIR")"
        git clone --filter=blob:none --no-checkout --sparse "$REPO" "$DIR"
      fi
      git -C "$DIR" remote set-url origin "$REPO"
      git -C "$DIR" sparse-checkout set apps/personal-memories
      git -C "$DIR" fetch --depth 1 --filter=blob:none origin "$REF"
      git -C "$DIR" -c advice.detachedHead=false checkout --force --detach "$REF"
      test "$(git -C "$DIR" rev-parse HEAD)" = "$REF"
      test -f "$DIR/apps/personal-memories/src/cli/auto-import.ts"
      echo "memories-auto-import: runner at $REF"
    EOT
  }
}

resource "null_resource" "dirs" {
  triggers = {
    log_dir  = local.log_dir
    drop_dir = local.drop_dir
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      LOG_DIR  = self.triggers.log_dir
      DROP_DIR = self.triggers.drop_dir
    }
    command = "mkdir -p \"$LOG_DIR\" \"$DROP_DIR\""
  }
}

resource "local_file" "plist" {
  filename        = local.plist_path
  file_permission = "0644"
  content = templatefile("${path.module}/launchd.plist.tftpl", {
    label      = local.plist_label
    node       = var.node_path
    script     = local.script
    runner_dir = local.runner_dir
    hour       = tonumber(local.schedule[0])
    minute     = tonumber(local.schedule[1])
    drop_dir   = replace(replace(replace(local.drop_dir, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
    log_dir    = local.log_dir
    env        = { for k, v in local.env : k => replace(replace(replace(v, "&", "&amp;"), "<", "&lt;"), ">", "&gt;") }
  })

  depends_on = [null_resource.runner, null_resource.dirs]
}

resource "null_resource" "launchd" {
  triggers = {
    plist_md5  = local_file.plist.content_md5
    runner_ref = var.runner_ref
    plist_path = local.plist_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      launchctl unload "${self.triggers.plist_path}" 2>/dev/null || true
      launchctl load "${self.triggers.plist_path}"
      echo "memories-auto-import: launchd agent loaded"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      launchctl unload "${self.triggers.plist_path}" 2>/dev/null || true
      echo "memories-auto-import: launchd agent unloaded"
    EOT
  }

  depends_on = [local_file.plist]
}
