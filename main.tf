resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}
resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

module "nfs-persistence" {
  source = "./modules/nfs-persistence"
  name   = "test"
}

module "traefik" {
  source = "./modules/traefik"

  cloudflare_api_key = var.cloudflare_api_key
  cloudflare_email   = var.cloudflare_email
}

module "open-webui" {
  source = "./modules/open-webui"
}

module "flowise" {
  source = "./modules/flowise"
}

module "postgresql" {
  source = "./modules/postgresql"
}

module "openspeedtest" {
  source = "./modules/openspeedtest"
}

module "calibre-web" {
  source = "./modules/calibre-web"
}
