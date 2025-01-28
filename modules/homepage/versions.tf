terraform {
  required_providers {
    helm = {
      source                = "hashicorp/helm"
      version               = ">= 2.0.0"
      configuration_aliases = [helm]
    }
  }
}

