output "issuer_name" {
  description = "Name of the ClusterIssuer to reference from Certificates"
  value       = var.issuer_name
}

output "issuer_kind" {
  description = "Kind of the issuer"
  value       = "ClusterIssuer"
}
