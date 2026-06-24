output "comfyui_url" {
  description = "ComfyUI web UI and API (local browser access)"
  value       = "http://localhost:${var.port}"
}

output "comfyui_docker_url" {
  description = "ComfyUI URL reachable from Docker containers via host bridge"
  value       = "http://host.docker.internal:${var.port}"
}

output "log_dir" {
  description = "Directory containing ComfyUI stdout/stderr logs"
  value       = pathexpand(var.log_dir)
}
