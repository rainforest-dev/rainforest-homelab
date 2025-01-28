resource "docker_container" "calibre-web" {
  image   = "lscr.io/linuxserver/calibre-web:latest"
  name    = "calibre-web"
  restart = "unless-stopped"
  ports {
    internal = 8083
    external = 8083
  }
  env = ["PUID=1000", "PGID=1000", "TZ=Asia/Taipei"]
  volumes {
    container_path = "/config"
    host_path      = "${abspath(path.root)}/configs/calibre-web"
  }
  volumes {
    container_path = "/books"
    host_path      = "/Users/rainforest/Library/CloudStorage/SynologyDrive-CalibreLibrary"
  }
}
