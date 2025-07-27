resource "helm_release" "postgresql" {
  name             = "${var.project_name}-postgresql"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      fullnameOverride = "${var.project_name}-postgresql"

      auth = {
        username           = var.postgres_user
        database           = var.postgres_database
        enablePostgresUser = true
      }

      primary = {
        persistence = {
          enabled = var.enable_persistence
          size    = var.storage_size
        }

        resources = {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = []
}
