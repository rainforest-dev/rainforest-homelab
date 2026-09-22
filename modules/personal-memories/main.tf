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
    "MEMORIES_DATA_DIR=${var.memories_data_path}",
  ]

  # Both mounts land on the path they already have on the host. `ingest` records
  # photo paths exactly as osxphotos reports them and the app opens them
  # verbatim, so a photo mounted anywhere else is a 404. Read-only throughout:
  # the album only ever reads, and these are the originals.
  volumes {
    container_path = var.memories_data_path
    host_path      = var.memories_data_path
    read_only      = true
  }

  volumes {
    container_path = var.photos_library_path
    host_path      = var.photos_library_path
    read_only      = true
  }

  lifecycle {
    precondition {
      condition     = var.memories_data_path != "" && var.photos_library_path != ""
      error_message = "personal-memories needs memories_data_path and photos_library_path. timeline.json records absolute host paths, so both have to be mounted at those same paths."
    }
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
