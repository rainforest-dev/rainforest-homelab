# MinIO Module

This module deploys MinIO as S3-compatible object storage for the homelab environment.

## Features

- MinIO deployment via Helm chart
- S3-compatible API for applications
- Web console for management  
- Configurable resource limits and persistence
- Automatic password generation with Kubernetes secrets
- Integration with Cloudflare Tunnel for external access

## Usage

### Basic Deployment

```hcl
module "minio" {
  source = "./modules/minio"

  project_name       = "homelab"
  environment        = "production"
  cpu_limit          = "500m"
  memory_limit       = "1Gi"
  enable_persistence = true
  storage_size       = "100Gi"
}
```

### Advanced Configuration

```hcl
module "minio" {
  source = "./modules/minio"

  project_name       = "homelab"
  environment        = "production"
  cpu_limit          = "1000m"
  memory_limit       = "2Gi"
  enable_persistence = true
  storage_size       = "500Gi"
  
  # MinIO specific settings
  minio_root_user     = "admin"
  replicas           = 1
  mode              = "standalone"
  console_enabled   = true
  
  # Use official MinIO Helm chart
  chart_repository = "https://charts.min.io/"
  chart_version    = "5.2.0"
}
```

## Outputs

- `resource_id`: MinIO Helm release name
- `service_url`: Internal S3 API endpoint
- `console_url`: Internal console endpoint (if enabled)
- `service_name`: Kubernetes service name
- `namespace`: Kubernetes namespace
- `access_key`: MinIO access key (root user)
- `secret_key`: MinIO secret key (sensitive)
- `s3_endpoint`: S3-compatible endpoint for applications

## External Access

When used with the Cloudflare Tunnel module:

- **Web Console**: `https://minio.yourdomain.com` (management interface)
- **S3 API**: `https://s3.yourdomain.com` (for applications and SDKs)

## S3 Client Configuration

### AWS CLI

```bash
aws configure set aws_access_key_id <access-key>
aws configure set aws_secret_access_key <secret-key>
aws configure set default.region us-east-1
aws configure set default.s3.signature_version s3v4

# Use with custom endpoint
aws --endpoint-url https://s3.yourdomain.com s3 ls
```

### MinIO Client (mc)

```bash
mc alias set homelab https://s3.yourdomain.com <access-key> <secret-key>
mc ls homelab/
```

### Application SDKs

Use any S3-compatible SDK with:
- **Endpoint**: `https://s3.yourdomain.com`
- **Access Key**: From Kubernetes secret
- **Secret Key**: From Kubernetes secret  
- **Region**: `us-east-1`

## Security Considerations

- Root credentials are auto-generated and stored in Kubernetes secrets
- Console access can be protected with Cloudflare Zero Trust
- S3 API endpoint should be used for programmatic access
- Consider creating dedicated IAM users for applications instead of using root credentials

## Storage

- Uses persistent volumes when `enable_persistence = true`
- Storage size should be appropriate for your data needs
- Default size is 100Gi but can be customized via `storage_size`
- Data is preserved across pod restarts and redeployments

## Resource Requirements

**Minimum**:
- CPU: 250m
- Memory: 512Mi
- Storage: 10Gi

**Recommended**:
- CPU: 500m-1000m
- Memory: 1-2Gi
- Storage: 100Gi+