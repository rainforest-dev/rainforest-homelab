locals {
  textfile_dir   = "/opt/homebrew/var/node_exporter/textfile_collector"
  script_dest    = "/opt/homebrew/bin/homelab-docker-stats-collect"
  plist_label    = "com.homelab.docker-stats-metrics"
  plist_dest     = "/Users/${var.macos_username}/Library/LaunchAgents/com.homelab.docker-stats-metrics.plist"
  node_args_file = "/opt/homebrew/etc/node_exporter.args"

  script_src  = abspath("${path.module}/collect.sh")
  script_hash = filesha256("${path.module}/collect.sh")
}

# 1. Textfile collector directory
resource "null_resource" "textfile_dir" {
  triggers = {
    dir = local.textfile_dir
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.textfile_dir}'"
  }
}

# 2. Enable textfile collector in node_exporter and restart it
resource "null_resource" "node_exporter_textfile" {
  depends_on = [null_resource.textfile_dir]

  triggers = {
    textfile_dir   = local.textfile_dir
    node_args_file = local.node_args_file
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "--collector.textfile.directory=${local.textfile_dir}" > '${local.node_args_file}'
      brew services restart node_exporter
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "" > '${self.triggers.node_args_file}'
      brew services restart node_exporter
    EOT
  }
}

# 3. Install the collection script
resource "null_resource" "collect_script" {
  triggers = {
    script_hash = local.script_hash
    script_dest = local.script_dest
    script_src  = local.script_src
  }

  provisioner "local-exec" {
    command = <<-EOT
      cp '${local.script_src}' '${local.script_dest}'
      chmod +x '${local.script_dest}'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f '${self.triggers.script_dest}'"
  }
}

# 4. Install and load the launchd plist (runs collect.sh every 30s)
resource "null_resource" "launchd_plist" {
  depends_on = [null_resource.collect_script, null_resource.textfile_dir]

  triggers = {
    script_hash  = local.script_hash
    textfile_dir = local.textfile_dir
    plist_dest   = local.plist_dest
    script_dest  = local.script_dest
    plist_label  = local.plist_label
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > '${local.plist_dest}' << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${local.plist_label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${local.script_dest}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>TEXTFILE_DIR</key>
    <string>${local.textfile_dir}</string>
    <key>DOCKER_BIN</key>
    <string>/usr/local/bin/docker</string>
  </dict>
  <key>StartInterval</key>
  <integer>30</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/opt/homebrew/var/log/docker-stats-metrics.log</string>
  <key>StandardErrorPath</key>
  <string>/opt/homebrew/var/log/docker-stats-metrics.err.log</string>
</dict>
</plist>
PLIST
      launchctl unload '${local.plist_dest}' 2>/dev/null || true
      launchctl load -w '${local.plist_dest}'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      launchctl unload '${self.triggers.plist_dest}' 2>/dev/null || true
      rm -f '${self.triggers.plist_dest}'
      rm -f '${self.triggers.textfile_dir}/docker_stats.prom'
    EOT
  }
}
