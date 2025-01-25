module "nfs-client-provisioner" {
  source = "./modules/nfs-client-provisioner"
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
