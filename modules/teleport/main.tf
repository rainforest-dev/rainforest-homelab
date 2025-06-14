provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "teleport" {
  name             = "teleport-agent"
  repository       = "https://charts.releases.teleport.dev"
  chart            = "teleport-kube-agent"
  version = "17.5.2"
  create_namespace = true
  namespace        = "homelab"

  values = [file("modules/teleport/prod-cluster-values.yaml")]
}