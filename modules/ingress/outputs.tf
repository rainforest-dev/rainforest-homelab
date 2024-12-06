output "ingress_id" {
  description = "The ID of the ingress resource."
  value       = kubernetes_pod.ingress.id
}