output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.vercel_board.name
}

output "data_volume" {
  description = "Docker volume holding the board's SQLite log and attachments"
  value       = docker_volume.data.name
}

output "board_url" {
  description = "BOARD_URL for vb on the host"
  value       = "http://127.0.0.1:${var.external_port}/api/board"
}

output "tunnel_service_url" {
  description = "Internal URL for Cloudflare Tunnel routing"
  value       = "http://host.docker.internal:${var.external_port}"
}
