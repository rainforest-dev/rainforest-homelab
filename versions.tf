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

  # Public images pull anonymously; a private one (bambii-focus) needs a token. Terraform
  # cannot read the macOS keychain where `docker login` keeps credentials, so it comes from
  # terraform.tfvars instead: a classic PAT with only read:packages.
  dynamic "registry_auth" {
    for_each = var.ghcr_read_token != "" ? [1] : []
    content {
      address  = "ghcr.io"
      username = var.ghcr_username
      password = var.ghcr_read_token
    }
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
