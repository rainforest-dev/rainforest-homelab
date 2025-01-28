terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

provider "helm" {
  alias = "orbstack"
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "orbstack"
}
