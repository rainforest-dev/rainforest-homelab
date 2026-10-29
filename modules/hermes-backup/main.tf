locals {
  plist_label = "tools.rainforest.hermes-backup"
  plist_path  = pathexpand("~/Library/LaunchAgents/${local.plist_label}.plist")
  backup_dir  = pathexpand(var.backup_dir)
  log_file    = pathexpand("~/Library/Logs/hermes-backup.log")
}

resource "local_file" "plist" {
  filename = local.plist_path
  content = templatefile("${path.module}/launchd.plist.tftpl", {
    label      = local.plist_label
    backup_dir = local.backup_dir
    hermes_bin = pathexpand(var.hermes_bin)
    keep       = var.keep
    hour       = var.hour
    minute     = var.minute
    log_file   = local.log_file
    home_dir   = pathexpand("~")
  })
}

resource "null_resource" "launchd" {
  triggers = {
    plist_md5  = local_file.plist.content_md5
    plist_path = local.plist_path
    label      = local.plist_label
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p "${local.backup_dir}"
      chmod 700 "${local.backup_dir}"
      launchctl bootout "gui/$(id -u)/${self.triggers.label}" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "${self.triggers.plist_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "launchctl bootout \"gui/$(id -u)/${self.triggers.label}\" 2>/dev/null || true"
  }
}
