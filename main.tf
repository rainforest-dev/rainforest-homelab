module "nfs-client-provisioner" {
  source = "./modules/nfs-client-provisioner"
}

module "ingress" {
  source = "./modules/ingress"
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
