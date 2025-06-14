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

module "n8n" {
  source = "./modules/n8n"
}

resource "docker_container" "dockerproxy" {
  image   = "ghcr.io/tecnativa/docker-socket-proxy:latest"
  name    = "dockerproxy"
  restart = "unless-stopped"
  env     = ["CONTAINERS=1", "SERVICES=1", "TASKS=1", "POST=0"]
  ports {
    internal = 2375
    external = 2375
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
}
