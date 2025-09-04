# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and custom manifests. The setup uses OrbStack as the local Kubernetes environment with Traefik as the ingress controller.

## Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications
- **Traefik**: Ingress controller with automatic HTTPS redirection
- **OrbStack**: Local Kubernetes cluster (context: `orbstack`)

### Module Structure
Each service is organized as a Terraform module in `modules/`:
- `traefik/`: Ingress controller with IngressRoute definitions for all services
- `postgresql/`: Database service for applications that need persistent storage  
- `nfs-persistence/`: Network storage for persistent volumes
- `minio/`: S3-compatible object storage service
- Application modules: `calibre-web/`, `flowise/`, `n8n/`, `open-webui/`, `openspeedtest/`, `homepage/`, `teleport/`

### Service Architecture
- All services run in the `homelab` namespace (except Traefik in `traefik` namespace)
- Services use `.k8s.orb.local` domain pattern for local access
- Traefik handles SSL termination and routing via IngressRoute CRDs
- Docker proxy container provides secure Docker socket access

## Common Commands

### Terraform Operations
```bash
# Initialize and plan infrastructure changes
terraform init
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format and validate
terraform fmt
terraform validate
```

### Kubernetes Operations
```bash
# Check cluster context (should be orbstack)
kubectl config current-context

# View running services
kubectl get pods -n homelab
kubectl get services -n homelab

# View Traefik dashboard port-forward
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=traefik) --namespace=traefik 8080:8080

# Get PostgreSQL password
echo $(kubectl get secret --namespace homelab postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Service Access
Services are available at:
- `openspeedtest.k8s.orb.local` - Network speed testing
- `open-webui.k8s.orb.local` - Open WebUI interface  
- `flowise.k8s.orb.local` - Flowise low-code AI workflows
- `calibre.k8s.orb.local` - Calibre Web ebook server
- `n8n.k8s.orb.local` - n8n automation platform
- `minio.k8s.orb.local` - MinIO object storage console
- `minio-api.k8s.orb.local` - MinIO S3 API endpoint

## Development Patterns

### Adding New Services
1. Create new module directory in `modules/[service-name]/`
2. Add `main.tf` with Helm release or Kubernetes manifests
3. Add service to main `main.tf` as a module
4. Add IngressRoute in `modules/traefik/main.tf` following existing patterns
5. Run `terraform plan` and `terraform apply`

### Traefik Ingress Configuration
IngressRoutes use `websecure` entrypoint and follow this pattern:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: [service-name]
  namespace: homelab
spec:
  entryPoints: ["websecure"]
  routes:
    - match: Host(`[service-name].k8s.orb.local`)
      kind: Rule
      services:
        - name: [service-name]
          port: [port-number]
```

### Configuration Management
- Helm values are stored in `values.yml` files within each module
- Terraform variables are defined in `variables.tf` and set in `terraform.tfvars`
- Sensitive data should use Kubernetes secrets (see commented Cloudflare example)

## Important Notes

- The repository uses OrbStack's local Kubernetes cluster
- All HTTP traffic is automatically redirected to HTTPS
- Cloudflare integration is configured but currently commented out
- Docker socket access is secured through a proxy container
- PostgreSQL service provides shared database functionality