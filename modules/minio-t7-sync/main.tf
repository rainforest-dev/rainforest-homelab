# Nightly mirror of the MinIO buckets onto the Samsung T7, which Synology Drive
# Client then backs up to the NAS. This is what makes the backups genuinely offsite.
#
# Why a sync instead of pointing MinIO's storage at the T7:
#   - The chart owns the /export mount, and past attempts to mount the T7 there
#     silently removed MinIO's data mount and crash-looped it (see modules/minio).
#   - Mirroring through the S3 API produces an object-consistent copy. Letting
#     Synology Drive copy MinIO's live data directory would capture torn writes,
#     so the NAS copy — the real last line of defence — could be unrestorable.
#   - MinIO keeps running if the T7 dies, and the T7 copy survives a Docker Desktop
#     reset (the failure that actually wiped the buckets in 2026-07).
#
# Safety: a bucket whose source is EMPTY is skipped rather than mirrored, so a
# MinIO fault can never propagate a deletion and wipe the offsite copy.

resource "kubernetes_cron_job_v1" "minio_sync" {
  metadata {
    name      = "minio-t7-sync"
    namespace = var.namespace
    labels    = { app = "minio-t7-sync" }
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata { labels = { app = "minio-t7-sync" } }
      spec {
        backoff_limit = 2
        template {
          metadata { labels = { app = "minio-t7-sync" } }
          spec {
            restart_policy = "Never"

            container {
              name    = "mc-mirror"
              image   = var.mc_image
              command = ["/bin/sh", "-c"]
              args = [
                <<-SH
                  set -e
                  # Credentials are passed as separate args, never embedded in the URL —
                  # the generated root password contains URL-unsafe characters.
                  mc alias set src "$MINIO_URL" "$MINIO_USER" "$MINIO_PASS" > /dev/null
                  rc=0
                  for b in ${join(" ", var.buckets)}; do
                    n=$(mc ls --recursive "src/$b" 2>/dev/null | wc -l)
                    if [ "$n" -eq 0 ]; then
                      echo "SKIP $b: source empty — refusing to mirror a wipe"
                      continue
                    fi
                    echo "MIRROR $b ($n objects)"
                    mc mirror --overwrite --remove "src/$b" "/t7/$b" || rc=1
                  done
                  echo "sync finished rc=$rc"
                  exit $rc
                SH
              ]

              env {
                name  = "MINIO_URL"
                value = var.minio_url
              }
              env {
                name = "MINIO_USER"
                value_from {
                  secret_key_ref {
                    name = var.minio_secret_name
                    key  = "rootUser"
                  }
                }
              }
              env {
                name = "MINIO_PASS"
                value_from {
                  secret_key_ref {
                    name = var.minio_secret_name
                    key  = "rootPassword"
                  }
                }
              }

              volume_mount {
                name       = "t7"
                mount_path = "/t7"
              }
            }

            volume {
              name = "t7"
              host_path {
                path = var.t7_path
                type = "DirectoryOrCreate"
              }
            }
          }
        }
      }
    }
  }
}
