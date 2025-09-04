## Services

### MinIO Object Storage

MinIO provides S3-compatible object storage for the homelab infrastructure.

- **Console**: https://minio.k8s.orb.local
- **S3 API**: https://minio-api.k8s.orb.local
- **Default credentials**: admin / minioadmin123
- **Storage**: 20Gi persistent volume

Access the MinIO console to create buckets, manage objects, and configure policies. The S3 API endpoint can be used by applications requiring object storage.

### PostgreSQL

- default port: 5432
- default user: postgres
- default password:

```bash
echo $(kubectl get secret --namespace homelab postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Traefik

```bash
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=traefik) --namespace=traefik 8080:8080
```