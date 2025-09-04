# MinIO Configuration Examples

This document provides examples of how to configure applications to use MinIO for object storage.

## Environment Variables

For applications that support S3-compatible storage, use these environment variables:

```bash
# S3 endpoint configuration
S3_ENDPOINT=https://minio-api.k8s.orb.local
S3_REGION=us-east-1
S3_ACCESS_KEY=admin
S3_SECRET_KEY=minioadmin123
S3_BUCKET=my-app-bucket

# Alternative format for some applications
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=minioadmin123
```

## Kubernetes Service Discovery

For applications running within the cluster, use internal service names:

```yaml
# Direct service access (within cluster)
- name: S3_ENDPOINT
  value: "http://minio:9000"
- name: S3_ACCESS_KEY
  value: "admin"
- name: S3_SECRET_KEY
  value: "minioadmin123"
```

## Creating Buckets

Buckets can be created via:
1. MinIO Console: https://minio.k8s.orb.local
2. AWS CLI or MinIO Client (mc)
3. Application initialization scripts

## Security Considerations

- Change default credentials in production
- Create dedicated access keys for each application
- Use bucket policies to restrict access
- Consider using Kubernetes secrets for credentials

## Application Examples

### Backup Applications
- Configure backup tools to use MinIO as S3 storage
- Create dedicated buckets for different backup types

### File Storage Applications  
- Use MinIO for user uploads and file storage
- Configure applications to use S3 APIs for file operations

### IoT Data Storage
- Store sensor data and logs in MinIO buckets
- Use S3 APIs for batch uploads and retrieval