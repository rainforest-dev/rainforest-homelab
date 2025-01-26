

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "orbstack"
}

resource "kubernetes_persistent_volume" "nfs-pv" {
  metadata {
    name = "${var.name}-pv"
  }
  spec {
    storage_class_name = "nfs"
    access_modes       = ["ReadWriteMany"]
    capacity = {
      storage = var.capacity
    }
    persistent_volume_source {
      nfs {
        server = "rainforest-nas"
        path   = "/volume1/persistent_volumes"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "nfs-pvc" {
  metadata {
    name      = "${var.name}-pvc"
    namespace = var.namespace
  }
  spec {
    storage_class_name = "nfs"
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = {
        storage = var.requests
      }
    }
    volume_name = kubernetes_persistent_volume.nfs-pv.metadata[0].name
  }
}
