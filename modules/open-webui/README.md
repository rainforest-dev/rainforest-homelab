# Open WebUI Storage Integration

## Overview

The Open WebUI module has been refactored to use centralized storage instead of local persistent volumes:

- **PostgreSQL**: Stores application configuration and session data
- **MinIO**: Stores user uploads, exports, and other file data via S3-compatible API

## Configuration

### Database Storage (PostgreSQL)

When `enable_postgresql = true` in your main configuration:

- Open WebUI automatically connects to the shared PostgreSQL instance
- Uses database connection string: `postgresql://postgres:<password>@homelab-postgresql.homelab.svc.cluster.local:5432/homelab`
- Password is automatically retrieved from Kubernetes secrets
- Local SQLite storage is disabled when external database is enabled

### File Storage (MinIO S3)

When `enable_minio = true` in your main configuration:

- Open WebUI uses MinIO S3-compatible API for file storage
- Dedicated bucket `openwebui` is automatically created
- S3 endpoint: `http://homelab-minio.homelab.svc.cluster.local:9000`
- Access credentials are automatically retrieved from Kubernetes secrets

## Environment Variables

The module automatically configures these environment variables for Open WebUI:

### Database Configuration
- `databaseUrl`: PostgreSQL connection string (when external database enabled)

### S3 Storage Configuration
- `AWS_ACCESS_KEY_ID`: MinIO access key
- `AWS_SECRET_ACCESS_KEY`: MinIO secret key  
- `AWS_S3_ENDPOINT_URL`: MinIO S3 API endpoint
- `AWS_DEFAULT_REGION`: S3 region (default: us-east-1)
- `AWS_S3_BUCKET`: Bucket name for Open WebUI files

## Automatic Setup

### Bucket Creation

A Kubernetes job automatically:
1. Waits for MinIO to be ready
2. Creates the `openwebui` bucket if it doesn't exist
3. Sets appropriate permissions for file access

### Secret Management

The module automatically retrieves passwords from Kubernetes secrets:
- PostgreSQL password from `homelab-postgresql` secret
- MinIO credentials from `homelab-minio` secret

## Migration Impact

### Benefits
- **Centralized Storage**: All data in PostgreSQL and MinIO
- **Backup Simplicity**: Single backup strategy for all services
- **Scalability**: Database and object storage can be scaled independently
- **Consistency**: Same storage pattern across all homelab services

### Changes from Previous Setup
- Local SQLite database → PostgreSQL database
- Local file uploads → MinIO S3 storage
- Persistent volumes disabled when external storage is used
- No NFS dependency required

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL service status
kubectl get pods -n homelab -l app.kubernetes.io/name=postgresql

# Check database connection from Open WebUI pod
kubectl exec -n homelab deployment/homelab-open-webui -- sh -c "pg_isready -h homelab-postgresql -p 5432"
```

### S3 Storage Issues
```bash
# Check MinIO service status
kubectl get pods -n homelab -l app.kubernetes.io/name=minio

# Check bucket creation job
kubectl get jobs -n homelab create-openwebui-bucket
kubectl logs -n homelab job/create-openwebui-bucket

# Test S3 connection from Open WebUI pod
kubectl exec -n homelab deployment/homelab-open-webui -- sh -c "curl -I http://homelab-minio:9000"
```

### View Configuration
```bash
# Check Open WebUI environment variables
kubectl get deployment -n homelab homelab-open-webui -o yaml | grep -A 20 env:

# View generated Helm values
terraform state show module.open-webui.helm_release.open-webui
```

## Security Considerations

- Database passwords stored securely in Kubernetes secrets
- MinIO credentials managed via Kubernetes secrets  
- S3 bucket access restricted to Open WebUI namespace
- No sensitive data in Terraform state files

## Compatibility

This configuration is compatible with:
- Open WebUI v0.3.x and later (supports PostgreSQL via `databaseUrl`)
- S3 API support may vary by Open WebUI version
- All existing homelab services and infrastructure