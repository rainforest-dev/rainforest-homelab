# cert-manager with a Let's Encrypt DNS-01 issuer backed by Cloudflare.
# DNS-01 is the only challenge that works here: nothing on the Mac is reachable
# on public port 80/443 except through Cloudflare Tunnel, and it also allows the
# wildcard certificates Teleport needs for app access (*.tp.<domain>).

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      # Resolve DNS-01 challenges against public resolvers, not the cluster's,
      # so a split-horizon record for the same name can never fake a pass.
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53",
      ]
    })
  ]

  wait    = true
  timeout = 600
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = var.namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  depends_on = [helm_release.cert_manager]
}

# kubectl_manifest (not kubernetes_manifest) because the ClusterIssuer CRD does
# not exist until the Helm release above has been applied.
resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.issuer_name
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "${var.issuer_name}-account-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                key  = "api-token"
              }
            }
          }
        }]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}
