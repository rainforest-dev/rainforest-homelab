output "ingress_id" {
  description = "The ID of the ingress resource."
  value       = module.ingress.ingress_id
}

output "flowise_id" {
  value = module.flowise.flowise_id
}