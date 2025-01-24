

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "orbstack"
}

resource "kubernetes_persistent_volume" "nfs-pv" {
  metadata {
    name = "nfs-pv"
  }
  spec {
    storage_class_name = "nfs"
    access_modes       = ["ReadWriteMany"]
    capacity = {
      storage = "10Gi"
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
    name = "nfs-pvc"
  }
  spec {
    storage_class_name = "nfs"
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.nfs-pv.metadata[0].name
  }
}
