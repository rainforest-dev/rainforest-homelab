resource "docker_container" "loop_observatory" {
  image   = var.image
  name    = "${var.project_name}-loop-observatory"
  restart = "always"

  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  memory_swap = -1

  ports {
    internal = 3003
    external = var.external_port
  }

  # Every LOOP_* path is set explicitly. Their in-code defaults hang off $HOME,
  # which inside this container is /root: the greenlight reads would fail closed
  # and every project would silently report no executor ready.
  # LOOP_HOSTS_YAML is not here — host declarations are baked into the image so
  # that a declaration change is a release, not a mount.
  env = [
    "NODE_ENV=production",
    "VAULT_PATH=/vault",
    "USAGE_MACHINE=${var.usage_machine}",
    "LOOP_GREENLIGHT_DIR=/loop/greenlight",
    "LOOP_GREENLIGHT_OUTBOX_DIR=/loop/greenlight-outbox",
    "LOOP_CONFIG_PATH=/loop/config.yaml",
    "SITE_URL=${var.site_url}",
    "LOOP_SYNC_URL=${var.loop_sync_url}",
    "LOOP_SYNC_TOKEN_FILE=/run/secrets/sync-token",
    "LOOP_ENGINE_BUNDLE=/engine/loop-engine.tar.gz",
  ]

  # Read-write, unlike rss-manager's vault mount: taskDecision, taskNote,
  # greenlightOutbox and the enrollment store all write here.
  volumes {
    container_path = "/vault"
    host_path      = var.vault_path
    read_only      = false
  }

  volumes {
    container_path = "/loop"
    host_path      = var.loop_state_path
    read_only      = false
  }

  # The engine tarball an enrolling machine downloads. Without it
  # /api/enroll/bundle and /api/enroll/bundle.sha256 both answer 503, and the
  # setup page has nothing to hand a new executor.
  volumes {
    container_path = "/engine"
    host_path      = var.loop_engine_bundle_path
    read_only      = true
  }

  volumes {
    container_path = "/run/secrets/sync-token"
    host_path      = var.loop_sync_token_path
    read_only      = true
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "environment"
    value = var.environment
  }
  labels {
    label = "service"
    value = "loop-observatory"
  }
}
