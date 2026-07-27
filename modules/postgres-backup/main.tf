# Nightly logical dump of the Mac Postgres (holds all n8n workflows/credentials + flowise).
# A logical pg_dumpall is restorable independently and safe on a live DB — unlike copying the
# raw data dir. Writes gzipped dumps to a hostPath the docker-volume-backup container also
# mounts, so the dump reaches MinIO (and Synology if enabled) through the same pipeline.

resource "kubernetes_cron_job_v1" "pg_dump" {
  metadata {
    name      = "postgres-backup"
    namespace = var.namespace
    labels    = { app = "postgres-backup" }
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata { labels = { app = "postgres-backup" } }
      spec {
        backoff_limit = 2
        template {
          metadata { labels = { app = "postgres-backup" } }
          spec {
            restart_policy = "Never"

            container {
              name    = "pg-dump"
              image   = var.postgres_image
              command = ["/bin/sh", "-c"]
              args = [
                "set -eu; ts=$(date +%Y%m%d-%H%M%S); out=/dump/pg_dumpall-$ts.sql.gz; pg_dumpall -h \"$PGHOST\" -U postgres | gzip > \"$out\"; echo \"wrote $out ($(wc -c < \"$out\") bytes)\"; ls -1t /dump/pg_dumpall-*.sql.gz | tail -n +${var.keep + 1} | xargs -r rm -f"
              ]

              env {
                name  = "PGHOST"
                value = "homelab-postgresql"
              }
              env {
                name = "PGPASSWORD"
                value_from {
                  secret_key_ref {
                    name = var.pg_secret_name
                    key  = var.pg_secret_key
                  }
                }
              }

              volume_mount {
                name       = "dump"
                mount_path = "/dump"
              }
            }

            volume {
              name = "dump"
              host_path {
                path = var.dump_host_path
                type = "DirectoryOrCreate"
              }
            }
          }
        }
      }
    }
  }
}
