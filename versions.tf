terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {
  host = var.docker_host

  # Without a registry_auth block the provider talks to registries anonymously, which only
  # works for public images. This one reads the Docker config on the machine running
  # terraform, whose credsStore (osxkeychain) holds the `docker login` for ghcr.io, so private
  # ghcr images resolve and pull like public ones.
  registry_auth {
    address     = "ghcr.io"
    config_file = pathexpand("~/.docker/config.json")
  }
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubernetes_context
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubernetes_context
}

provider "kubectl" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubernetes_context
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
