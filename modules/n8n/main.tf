provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "n8n" {
  name             = "n8n"
  repository       = "oci://8gears.container-registry.com/library/"
  chart            = "n8n"
  create_namespace = true
  namespace        = "homelab"
}
