output "cronjob_name" {
  value = kubernetes_cron_job_v1.minio_sync.metadata[0].name
}
