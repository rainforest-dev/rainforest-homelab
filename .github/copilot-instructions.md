# Copilot Instructions for Rainforest Homelab

This project is a **Terraform-based homelab infrastructure** that deploys self-hosted applications to Docker Desktop Kubernetes with **Cloudflare Tunnel** for secure external access.

## 🏗️ Architecture Overview

### Core Infrastructure Pattern

- **Docker Desktop** Kubernetes cluster (context: `docker-desktop`)
- **Cloudflare Tunnel** replaces traditional ingress - provides SSL termination, DNS, and Zero Trust auth
- **Terraform modules** for each service following standardized patterns
- **Docker volumes** for persistence instead of traditional PVCs
- **MinIO S3 storage** for centralized object storage across all services

### Critical Flow Understanding

```
External Request → Cloudflare Edge → Tunnel → cloudflared pods → K8s Services
```

The **key architectural decision**: This homelab uses Cloudflare Tunnel to avoid exposing home IP addresses while providing enterprise-grade SSL certificates and optional Zero Trust authentication.

## 🔧 Essential Development Patterns

### Adding New Services (Multi-Step Process)

When adding a service, you MUST update these locations:

1. **Create module** in `modules/[service-name]/` with standard structure:

   ```
   main.tf       # Helm release or Docker container
   variables.tf  # Standard vars: project_name, environment, cpu_limit, etc.
   outputs.tf    # Include service_url output
   ```

2. **Add to main.tf** as module with standard variables

3. **Update Cloudflare tunnel config** in `modules/cloudflare-tunnel/main.tf`:
   - Add ingress rule in `cloudflare_zero_trust_tunnel_cloudflared_config`
   - Add to DNS records `for_each` list in `cloudflare_record.services`
   - Add to Zero Trust apps if authentication needed (MinIO console gets auth, S3 API does not)

### Module Standardization (Critical Pattern)

All modules follow this interface:

```hcl
# Standard variables every module accepts
project_name, environment, namespace
cpu_limit, memory_limit, storage_size
enable_persistence, chart_repository, chart_version

# Standard outputs every module provides
resource_id, service_url, service_name, namespace
```

### Cloudflare Tunnel Integration

**Ingress routing** handled in tunnel config, not K8s ingress:

```hcl
ingress_rule {
  hostname = "service.${var.domain_suffix}"
  service  = "http://service-name.homelab.svc.cluster.local:port"
}
```

**MinIO Special Case** - Dual endpoints required:
```hcl
# Console (management UI)
ingress_rule {
  hostname = "minio.${var.domain_suffix}"
  service  = "http://homelab-minio-console.homelab.svc.cluster.local:9001"
}

# S3 API (for applications)
ingress_rule {
  hostname = "s3.${var.domain_suffix}"
  service  = "http://homelab-minio.homelab.svc.cluster.local:9000"
}
```

## ⚙️ Configuration Management

### Two-Step Deployment Pattern

1. **Basic tunnel setup** - services publicly accessible via HTTPS
2. **Zero Trust auth** (optional) - email verification required

### Feature Flags Control Services

```hcl
enable_cloudflare_tunnel = true   # Main external access method
enable_postgresql = true          # Shared database
enable_minio = true               # S3-compatible object storage
enable_persistence = true         # Docker volume storage
```

### Environment-Specific Settings

Use `terraform.tfvars` for:

- `domain_suffix` - Your Cloudflare-managed domain
- `cloudflare_account_id` / `cloudflare_api_token` - Required for tunnel
- `allowed_email_domains` - Controls Zero Trust access
- `minio_storage_size` - MinIO storage allocation (default: 100Gi)

## 🚀 Common Operations

### Deployment Commands

```bash
# Standard deployment
terraform init && terraform plan && terraform apply

# Service-specific targeting
terraform apply -target="module.service-name"

# Force container recreation (for Docker services)
terraform apply -replace="module.service.docker_container.service"
```

### Docker Volume Management

```bash
# List project volumes
docker volume ls --filter label=project=homelab

# Backup strategy
docker run --rm -v VOLUME:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz -C /data .
```

### Cloudflare Tunnel Debugging

```bash
# Check tunnel connectivity
kubectl logs -n homelab -l app=cloudflared --tail=20

# View tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml
```

### MinIO S3 Storage Operations

```bash
# Get MinIO credentials
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-user}" | base64 --decode; echo
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-password}" | base64 --decode; echo

# Access via MinIO client
mc alias set homelab https://s3.yourdomain.com <access-key> <secret-key>
mc ls homelab/

# Use with applications via S3 API
# Endpoint: https://s3.yourdomain.com
# Console: https://minio.yourdomain.com
```

## 📁 Project Structure Intelligence

### Service Categories

- **Kubernetes services** (via tunnel): open-webui, flowise, n8n, homepage
- **Docker containers** (direct): calibre-web, openspeedtest, dockerproxy
- **Infrastructure**: cloudflare-tunnel, postgresql, minio, metrics-server, volume-management
- **Development tools**: mcpo (MCP-to-OpenAPI proxy for AI workflows)

### Legacy vs Active

- **Active**: `cloudflare-tunnel/`, `volume-management/`, all app modules
- **Legacy**: `traefik/` (replaced by tunnel), `coredns/`, `nfs-persistence/`

### Configuration Hierarchy

```
terraform.tfvars.example → terraform.tfvars (user config)
variables.tf (defaults) → module variables.tf (service-specific)
```

## 🔒 Security Considerations

### Cloudflare Tunnel Security

- **Home IP hidden** - tunnel creates secure outbound-only connection
- **Automatic SSL** - real certificates from Cloudflare, not self-signed
- **Zero Trust ready** - email domain/address-based access control

### Sensitive Data Handling

- `cloudflare_api_token`/`cloudflare_account_id` marked `sensitive = true`
- Never commit `terraform.tfvars` - use `.example` file as template
- Docker socket access secured via proxy container

## 🔄 Version Management

### Ansible Automation

The `automation/` directory contains Ansible playbooks for comprehensive version management:

```bash
cd automation && ./upgrade check    # Shows available updates
cd automation && ./upgrade all      # Upgrade all services
cd automation && ./upgrade SERVICE  # Upgrade specific service
```

**Features**:
- Beautiful table display of current vs latest versions
- Auto-updates Terraform module versions
- Safe deployment with confirmation prompts
- Support for Helm charts, OCI registries, and Docker images

**Important**: All upgrades update Terraform first, then use `terraform apply` for safety.

### Service Types for Updates

- **Helm charts**: Auto-updates `chart_version` in module call
- **OCI registries**: Manual check required, then Terraform update
- **Docker latest**: Force recreation with `terraform apply -replace`

## 🎯 When Working on This Codebase

### Always Consider

1. **Cloudflare tunnel routing** - services need ingress rules AND DNS records
2. **Module standardization** - follow the established variable/output patterns
3. **Docker Desktop context** - assumes local K8s cluster
4. **Volume management** - use the volume-management module for persistence
5. **Zero Trust implications** - new services may need access policies

### Don't

- Create traditional K8s ingress resources (tunnel handles routing)
- Hardcode domain names (use `var.domain_suffix`)
- Skip the standardized module structure
- Expose ports directly (tunnel provides external access)

### Quick Validation

- `terraform plan` before apply
- Check service appears in tunnel config
- Verify DNS record created in Cloudflare
- Test external access via domain
