output "persistent_volume_name" {
  description = "The name of the NFS Persistent Volume"
  value       = kubernetes_persistent_volume.nfs-pv.metadata[0].name
}

output "persistent_volume_claim_name" {
  description = "The name of the NFS Persistent Volume Claim"
  value       = kubernetes_persistent_volume_claim.nfs-pvc.metadata[0].name
}
