# configure the kubernetes provider to use the orbstack cluster
provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "orbstack"
}

resource "kubernetes_pod" "ingress" {
  metadata {
    name = "ingress"
    labels = {
      app = "ingress"
    }
  }

  spec {
    container {
      name  = "ingress"
      image = "nginx:latest"
    }
  }
}

# create a service
resource "kubernetes_service" "ingress" {
  metadata {
    name = "ingress"
  }
  spec {
    selector = {
      app = kubernetes_pod.ingress.metadata.0.labels.app
    }
    port {
      port = 80
    }
    type = "NodePort"
  }
  depends_on = [ kubernetes_pod.ingress ]
}