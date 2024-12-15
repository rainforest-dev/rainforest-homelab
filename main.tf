module "ingress" {
  source = "./modules/ingress"
}

module "flowise" {
  source = "./modules/flowise"
}

module "postgresql" {
  source = "./modules/postgresql"
}
