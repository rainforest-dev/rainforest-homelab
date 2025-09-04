# MinIO Object Storage Module

This module deploys MinIO as a centralized S3-compatible object storage service for the homelab infrastructure.

## Configuration

- **Service Name**: minio
- **Namespace**: homelab
- **Console Access**: `minio.k8s.orb.local`
- **S3 API Access**: `minio-api.k8s.orb.local`
- **Storage**: 20Gi persistent volume
- **Default Credentials**: admin / minioadmin123

## Usage

MinIO provides S3-compatible object storage that can be used by:
- Applications requiring file/object storage
- Backup and archival systems
- IoT devices for data storage
- Development and testing with S3-compatible APIs

## Security

- Access is secured through Traefik ingress with HTTPS
- Default credentials should be changed in production
- Storage is persistent across pod restarts
- Service is only accessible within the cluster network unless exposed through ingress

## Endpoints

- **Console (Web UI)**: https://minio.k8s.orb.local
- **S3 API**: https://minio-api.k8s.orb.local
- **Internal Service**: minio:9000 (API), minio-console:9001 (Console)