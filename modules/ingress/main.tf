# configure the helm provider to use the orbstack cluster
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "ingress" {
  name = "traefik"
  repository = "https://traefik.github.io/charts"
  chart = "traefik"
  create_namespace = true
  namespace = "homelab"
}
