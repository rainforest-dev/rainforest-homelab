resource "docker_container" "personal_memories" {
  image   = var.image
  name    = "${var.project_name}-personal-memories"
  restart = "always"

  memory = parseint(regex("([0-9]+)", var.memory_limit)[0], 10) * (
    can(regex("Gi", var.memory_limit)) ? 1024 * 1024 * 1024 :
    can(regex("Mi", var.memory_limit)) ? 1024 * 1024 : 1
  )
  memory_swap = -1

  ports {
    internal = 3004
    external = var.external_port
  }

  env = [
    "NODE_ENV=${var.node_env}",
    "MEMORIES_DATA_DIR=${var.data_dir}",
    "MEMORIES_NOTES_DIR=${var.notes_dir}",
  ]

  # Container path mirrors the host path: timeline.json stores absolute host paths for every photo.
  volumes {
    container_path = var.data_dir
    host_path      = var.data_dir
    read_only      = true
  }

  volumes {
    container_path = var.photos_library_path
    host_path      = var.photos_library_path
    read_only      = true
  }

  # Day notes are written into the Obsidian vault. Only this folder is writable;
  # the data directory and the Photos library above stay read-only.
  volumes {
    container_path = var.notes_dir
    host_path      = var.notes_dir
    read_only      = false
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
    value = "personal-memories"
  }
}
