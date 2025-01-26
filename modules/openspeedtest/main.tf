terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "openspeedtest" {
  name         = "openspeedtest/latest"
  keep_locally = false
}

resource "docker_container" "openspeedtest" {
  image = docker_image.openspeedtest.image_id
  name  = "openspeedtest"
  ports {
    internal = 3000
    external = 3000
  }
}
