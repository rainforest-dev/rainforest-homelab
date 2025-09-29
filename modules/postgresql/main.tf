# PostgreSQL + pgAdmin Docker Stack with External Storage
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Generate random password for PostgreSQL if not provided
resource "random_password" "postgres_password" {
  count   = var.postgres_password == "" ? 1 : 0
  length  = 20
  special = true
}

# Generate random password for pgAdmin if not provided
resource "random_password" "pgadmin_password" {
  count   = var.pgadmin_password == "" ? 1 : 0
  length  = 16
  special = false
}

locals {
  postgres_password = var.postgres_password != "" ? var.postgres_password : random_password.postgres_password[0].result
  pgadmin_password  = var.pgadmin_password != "" ? var.pgadmin_password : random_password.pgadmin_password[0].result
  external_storage_base = "/Volumes/Samsung T7 Touch/homelab-data"
}

# Create directories on external storage
resource "null_resource" "external_directories" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${local.external_storage_base}/postgresql"
      mkdir -p "${local.external_storage_base}/pgadmin"
      chmod 755 "${local.external_storage_base}/postgresql"
      chmod 755 "${local.external_storage_base}/pgadmin"
    EOT
  }
  
  triggers = {
    postgres_path = "${local.external_storage_base}/postgresql"
    pgadmin_path  = "${local.external_storage_base}/pgadmin"
  }
}

# Docker network for PostgreSQL stack
resource "docker_network" "postgres_network" {
  name = "${var.project_name}-postgres-network"
  
  labels {
    label = "project"
    value = var.project_name
  }
}

# PostgreSQL volume on external storage
resource "docker_volume" "postgres_data" {
  name   = "${var.project_name}-postgres-data"
  driver = "local"
  
  driver_opts = {
    type   = "none"
    o      = "bind"
    device = "${local.external_storage_base}/postgresql"
  }

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "postgresql"
  }

  labels {
    label = "storage_type"
    value = "external"
  }

  depends_on = [null_resource.external_directories]
}

# pgAdmin volume on external storage
resource "docker_volume" "pgadmin_data" {
  name   = "${var.project_name}-pgadmin-data"
  driver = "local"
  
  driver_opts = {
    type   = "none"
    o      = "bind"
    device = "${local.external_storage_base}/pgadmin"
  }

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "pgadmin"
  }

  labels {
    label = "storage_type"
    value = "external"
  }

  depends_on = [null_resource.external_directories]
}

# PostgreSQL container with advanced backup features
resource "docker_container" "postgres" {
  image   = "postgres:${var.postgres_version}"
  name    = "${var.project_name}-postgresql"
  restart = "unless-stopped"

  # Network configuration
  networks_advanced {
    name = docker_network.postgres_network.name
  }

  # Port mapping for Tailscale access
  ports {
    internal = 5432
    external = var.postgres_external_port
  }

  # Environment variables
  env = [
    "POSTGRES_DB=${var.postgres_database}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${local.postgres_password}",
    "PGDATA=/var/lib/postgresql/data/pgdata"
  ]

  # Volume mounts
  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.postgres_data.name
  }

  # Mount custom PostgreSQL configuration
  volumes {
    container_path = "/etc/postgresql/postgresql.conf"
    host_path      = "${abspath(path.module)}/configs/postgresql.conf"
    read_only      = true
  }

  # Mount initialization scripts
  volumes {
    container_path = "/docker-entrypoint-initdb.d/init-advanced-backup.sql"
    host_path      = "${abspath(path.module)}/scripts/init-advanced-backup.sql"
    read_only      = true
  }

  # Health check
  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.postgres_user} -d ${var.postgres_database}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Resource limits
  memory = var.postgres_memory_limit

  # Labels
  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "postgresql"
  }

  labels {
    label = "environment"
    value = var.environment
  }
}

# pgAdmin container
resource "docker_container" "pgadmin" {
  image   = "dpage/pgadmin4:${var.pgadmin_version}"
  name    = "${var.project_name}-pgadmin"
  restart = "unless-stopped"

  # Network configuration
  networks_advanced {
    name = docker_network.postgres_network.name
  }

  # Port mapping for Tailscale access
  ports {
    internal = 80
    external = var.pgadmin_external_port
  }

  # Environment variables
  env = [
    "PGADMIN_DEFAULT_EMAIL=${var.pgadmin_email}",
    "PGADMIN_DEFAULT_PASSWORD=${local.pgadmin_password}",
    "PGADMIN_CONFIG_SERVER_MODE=True",
    "PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=False"
  ]

  # Volume mounts
  volumes {
    container_path = "/var/lib/pgadmin"
    volume_name    = docker_volume.pgadmin_data.name
  }

  # Resource limits
  memory = var.pgadmin_memory_limit

  # Labels
  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "service"
    value = "pgadmin"
  }

  labels {
    label = "environment"
    value = var.environment
  }

  depends_on = [docker_container.postgres]
}

# PostgreSQL is ready - services will self-register their databases
# No centralized database creation - each service manages its own database lifecycle

# pgBackRest backup container for incremental backups
# Temporarily disabled due to image availability issues
# resource "docker_container" "pgbackrest" {
#   count   = var.backup_enabled ? 1 : 0
#   image   = "pgbackrest/pgbackrest:latest"
#   name    = "${var.project_name}-pgbackrest"
#   restart = "unless-stopped"
#
#   # Network configuration
#   networks_advanced {
#     name = docker_network.postgres_network.name
#   }
#
#   # Environment variables
#   env = [
#     "PGBACKREST_STANZA=homelab",
#     "PGBACKREST_LOG_LEVEL_CONSOLE=info",
#     "POSTGRES_HOST=${docker_container.postgres.name}",
#     "POSTGRES_PORT=5432",
#     "POSTGRES_USER=${var.postgres_user}",
#     "POSTGRES_PASSWORD=${local.postgres_password}"
#   ]
#
#   # Volume mounts
#   volumes {
#     container_path = "/backup"
#     host_path      = "${local.external_storage_base}/backups"
#   }
#
#   volumes {
#     container_path = "/var/lib/postgresql/data"
#     volume_name    = docker_volume.postgres_data.name
#     read_only      = true
#   }
#
#   # Mount pgBackRest configuration
#   volumes {
#     container_path = "/etc/pgbackrest/pgbackrest.conf"
#     host_path      = "${abspath(path.module)}/configs/pgbackrest.conf"
#     read_only      = true
#   }
#
#   # pgBackRest daemon mode for continuous WAL archiving
#   command = ["pgbackrest", "--stanza=homelab", "--config=/etc/pgbackrest/pgbackrest.conf", "server"]
#
#   # Resource limits
#   memory = 256
#
#   # Labels
#   labels {
#     label = "project"
#     value = var.project_name
#   }
#
#   labels {
#     label = "service"
#     value = "pgbackrest"
#   }
#
#   depends_on = [docker_container.postgres, null_resource.external_directories]
# }

# Backup monitoring and NAS sync container
# Temporarily disabled due to pgBackRest issues
# resource "docker_container" "backup_monitor" {
#   count   = var.backup_enabled ? 1 : 0
#   image   = "postgres:${var.postgres_version}"
#   name    = "${var.project_name}-backup-monitor"
#   restart = "unless-stopped"
#
#   # Network configuration
#   networks_advanced {
#     name = docker_network.postgres_network.name
#   }
#
#   # Environment variables
#   env = [
#     "POSTGRES_HOST=${docker_container.postgres.name}",
#     "POSTGRES_USER=${var.postgres_user}",
#     "POSTGRES_PASSWORD=${local.postgres_password}",
#     "NAS_IP=100.84.80.123",
#     "PROJECT_NAME=${var.project_name}"
#   ]
#
#   # Volume mounts
#   volumes {
#     container_path = "/backup"
#     host_path      = "${local.external_storage_base}/backups"
#   }
#
#   # Monitor pg_cron jobs and sync to NAS
#   command = [
#     "sh", "-c",
#     <<-EOT
#     apt-get update && apt-get install -y rsync openssh-client postgresql-client
#     while true; do
#       echo "Checking backup status and syncing to NAS..."
#       
#       # Sync backups to NAS
#       if ping -c 1 100.84.80.123 > /dev/null 2>&1; then
#         rsync -avz /backup/ root@100.84.80.123:/volume1/backups/homelab/postgresql/ 2>/dev/null || echo "NAS sync failed"
#       fi
#       
#       sleep 3600  # Check every hour
#     done
#     EOT
#   ]
#
#   # Resource limits  
#   memory = 128
#
#   # Labels
#   labels {
#     label = "project"
#     value = var.project_name
#   }
#
#   labels {
#     label = "service"
#     value = "backup-monitor"
#   }
#
#   depends_on = [docker_container.postgres]
# }