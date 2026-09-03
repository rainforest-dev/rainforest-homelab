# Nightly backup of Mac Mini stateful data → MinIO (localhost) → (optionally) Synology.
# Mirrors the Pi's offen/docker-volume-backup module, retargeted with AWS_S3_PATH=mac and
# the Mac's own volumes. Backs up the non-regenerable app volumes plus the Postgres logical
# dump directory produced by the postgres-backup CronJob — so one tool ships both.
#
# Deliberately EXCLUDED: homelab-calibre-web-books (large, re-downloadable library) and
# homelab-whisper-models (re-downloaded on demand). Add them here if that changes.

resource "docker_image" "backup" {
  name = "offen/docker-volume-backup:${var.image_version}"
}

resource "docker_container" "backup" {
  image = docker_image.backup.image_id
  name  = "homelab-docker-volume-backup"

  # "always", not "unless-stopped": Docker Desktop stops containers through the API on backend
  # restart, which marks them stopped, and "unless-stopped" then leaves them down for good.
  # That silently disabled the Mac backup for 14 days on 2026-08-06.
  restart = "always"

  env = [
    "BACKUP_CRON_EXPRESSION=${var.backup_schedule}",
    "AWS_S3_BUCKET_NAME=${var.minio_bucket}",
    "AWS_ACCESS_KEY_ID=${var.minio_access_key}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_secret_key}",
    "AWS_ENDPOINT=${var.minio_endpoint}",
    "AWS_ENDPOINT_PROTO=http",
    "AWS_S3_FORCE_PATH_STYLE=true",
    "AWS_S3_PATH=mac",
    "BACKUP_RETENTION_DAYS=${var.retention_days}",
    "BACKUP_PRUNING_PREFIX=backup-",
    "BACKUP_STOP_DURING_BACKUP_LABEL=docker-volume-backup.stop-during-backup",
    "BACKUP_FILENAME=backup-%Y%m%d-%H%M%S.tar.gz",
  ]

  # Docker socket — offen needs it to honour stop-during-backup labels.
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  # Non-regenerable app volumes (read-only).
  volumes {
    volume_name    = "homelab-calibre-web-config"
    container_path = "/backup/calibre-web-config"
    read_only      = true
  }
  volumes {
    volume_name    = "homelab-personal-calibre-app-data"
    container_path = "/backup/personal-calibre"
    read_only      = true
  }
  volumes {
    volume_name    = "homelab-rss-manager-app-data"
    container_path = "/backup/rss-manager"
    read_only      = true
  }

  # Postgres logical dumps (all n8n/flowise data) produced by the postgres-backup CronJob.
  volumes {
    host_path      = var.postgres_dump_host_path
    container_path = "/backup/postgres"
    read_only      = true
  }
}
