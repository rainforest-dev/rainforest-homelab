locals {
  dmg_name  = "BlueBubbles-${var.app_version}-arm64.dmg"
  dmg_url   = "https://github.com/BlueBubblesApp/bluebubbles-server/releases/download/v${var.app_version}/${local.dmg_name}"
  cache_dir = pathexpand("~/Library/Caches/homelab-bluebubbles")
  app_path  = "${var.app_dir}/BlueBubbles.app"
}

resource "null_resource" "install" {
  triggers = {
    version  = var.app_version
    sha256   = var.dmg_sha256
    app_path = local.app_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${local.cache_dir}"
      dmg="${local.cache_dir}/${local.dmg_name}"
      if ! echo "${var.dmg_sha256}  $dmg" | shasum -a 256 -c - >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$dmg.part" "${local.dmg_url}"
        echo "${var.dmg_sha256}  $dmg.part" | shasum -a 256 -c -
        mv "$dmg.part" "$dmg"
      fi
      mnt="$(mktemp -d)"
      hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" >/dev/null
      trap 'hdiutil detach "$mnt" -quiet || true; rmdir "$mnt" 2>/dev/null || true' EXIT
      osascript -e 'tell application "BlueBubbles" to quit' 2>/dev/null || true
      rm -rf "${local.app_path}"
      ditto "$mnt/BlueBubbles.app" "${local.app_path}"
      codesign --verify --deep --strict "${local.app_path}"
      spctl --assess --type execute "${local.app_path}"
    EOT
  }
}
