provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

resource "helm_release" "open-webui" {
  name             = "open-webui"
  repository       = "https://helm.openwebui.com/"
  chart            = "open-webui"
  create_namespace = true
  namespace        = "homelab"

  set {
    name  = "ollama.enabled"
    value = "false"
  }
}
