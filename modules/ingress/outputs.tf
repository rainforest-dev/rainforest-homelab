output "ingress_id" {
  description = "The ID of the ingress resource."
  value       = helm_release.ingress.id
}