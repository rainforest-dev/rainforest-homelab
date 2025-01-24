provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "openspeedtest" {
  name             = "openspeedtest"
  repository       = "https://openspeedtest.github.io/Helm-chart/"
  chart            = "openspeedtest"
  create_namespace = true
  namespace        = "homelab"
}
