provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "flowise" {
  name = "flowise"
  repository = "https://cowboysysop.github.io/charts"
  chart = "flowise"
  create_namespace = true
  namespace = "homelab"
}