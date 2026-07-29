# Alerts when a backup stops arriving — the gap that let the 2026-07 outage run for
# days. Velero and the Pi's docker-volume-backup both failed every night with
# NoSuchBucket, and nothing said a word; the failure was only found by hand.
#
# What it checks: the age of the newest file in each bucket directory of the T7
# offsite copy. That single check covers the WHOLE chain end to end — a backup that
# never ran, an upload that failed, a sync that broke, or a bucket that vanished all
# surface the same way: the offsite copy stops getting newer.
#
# Where the alert goes: the n8n webhook that appends to the Obsidian daily note, so
# it lands in the notebook that is actually read every day. The job also exits
# non-zero so a stale backup is visible in `kubectl get jobs` too.
#
# Deliberately NOT Prometheus: Velero's metrics are not scraped and the Mac's
# cluster is not in Prometheus at all, so neither pipeline is observable there.

resource "kubernetes_cron_job_v1" "backup_monitor" {
  metadata {
    name      = "backup-monitor"
    namespace = var.namespace
    labels    = { app = "backup-monitor" }
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 7

    job_template {
      metadata { labels = { app = "backup-monitor" } }
      spec {
        backoff_limit = 0
        template {
          metadata { labels = { app = "backup-monitor" } }
          spec {
            restart_policy = "Never"

            container {
              name    = "check"
              image   = var.image
              command = ["/bin/sh", "-c"]
              args = [
                <<-SH
                  set -u
                  STALE=""
                  for b in ${join(" ", var.buckets)}; do
                    fresh=$(find "/t7/$b" -type f -mmin -${var.max_age_minutes} 2>/dev/null | wc -l)
                    total=$(find "/t7/$b" -type f 2>/dev/null | wc -l)
                    if [ "$fresh" -eq 0 ]; then
                      echo "STALE   $b (files=$total, none newer than ${var.max_age_minutes}m)"
                      STALE="$STALE $b"
                    else
                      echo "OK      $b ($fresh recent of $total files)"
                    fi
                  done

                  if [ -z "$STALE" ]; then
                    echo "all backups fresh"
                    exit 0
                  fi

                  # Report to the daily note. Keep going even if the webhook is down —
                  # the non-zero exit below still records the failure in Kubernetes.
                  BODY="{\"event\":\"backup_stale\",\"detail\":\"no new offsite backup in ${var.max_age_minutes}m:$STALE\",\"ts\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}"
                  wget -q -O- --timeout=15 \
                    --header='Content-Type: application/json' \
                    --post-data="$BODY" \
                    '${var.webhook_url}' || echo "WARN: could not reach the n8n webhook"

                  echo "stale buckets:$STALE"
                  exit 1
                SH
              ]

              volume_mount {
                name       = "t7"
                mount_path = "/t7"
                read_only  = true
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
