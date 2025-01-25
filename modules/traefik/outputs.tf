output "traefik_id" {
  description = "The ID of the traefik resource."
  value       = helm_release.traefik.id
}