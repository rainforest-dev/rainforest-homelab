# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and custom manifests. The setup uses Docker Desktop as the local Kubernetes environment with Traefik as the ingress controller and Docker volumes for persistent storage.

## Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications
- **Traefik**: Ingress controller with automatic HTTPS redirection
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Module Structure
Each service is organized as a Terraform module in `modules/`:
- `traefik/`: Ingress controller with IngressRoute definitions for all services
- `postgresql/`: Database service for applications that need persistent storage  
- `volume-management/`: Docker volume management for persistent storage
- `nfs-persistence/`: Network storage for persistent volumes (legacy)
- Application modules: `calibre-web/`, `flowise/`, `n8n/`, `open-webui/`, `openspeedtest/`, `homepage/`, `teleport/`

### Standardized Module Structure
All modules follow a consistent structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

### Service Architecture
- All services run in the `homelab` namespace (except Traefik in `traefik` namespace)
- Services use configurable domain suffix (default: `localhost`)
- Traefik handles SSL termination and routing via IngressRoute CRDs
- Docker proxy container provides secure Docker socket access
- Docker volumes provide managed persistent storage

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
# Check cluster context (should be docker-desktop)
kubectl config current-context

# View running services
kubectl get pods -n homelab
kubectl get services -n homelab

# View Traefik dashboard port-forward
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=traefik) --namespace=traefik 8080:8080

# Get PostgreSQL password
echo $(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Docker Volume Operations
```bash
# List all project volumes
docker volume ls --filter label=project=homelab

# Inspect a specific volume
docker volume inspect homelab-calibre-web-config

# Backup a volume
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar czf /backup/calibre-config-backup.tar.gz -C /data .

# Restore a volume
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar xzf /backup/calibre-config-backup.tar.gz -C /data
```

### Service Access
Services are available at (using configurable domain suffix):
- `openspeedtest.localhost` - Network speed testing
- `open-webui.localhost` - Open WebUI interface  
- `flowise.localhost` - Flowise low-code AI workflows
- `calibre.localhost` - Calibre Web ebook server
- `n8n.localhost` - n8n automation platform
- `homepage.localhost` - Homepage dashboard
- `teleport.localhost` - Teleport access proxy

Note: Domain suffix is configurable via `domain_suffix` variable in `terraform.tfvars`

## Development Patterns

### Adding New Services
1. Create new module directory in `modules/[service-name]/`
2. Create standardized module files:
   - `main.tf`: Main resource definitions
   - `variables.tf`: Standard variables (project_name, environment, etc.)
   - `outputs.tf`: Resource outputs including service_url
   - `versions.tf`: Provider constraints (if needed)
3. Add service to main `main.tf` as a module with standard variables
4. Add IngressRoute in `modules/traefik/main.tf` following existing patterns
5. For persistent storage, use the `volume-management` module
6. Run `terraform plan` and `terraform apply`

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
- **Centralized Variables**: Common settings defined in root `variables.tf`
- **Environment Configuration**: Use `terraform.tfvars` for environment-specific values
- **Module Variables**: Each module has standardized variables for consistency
- **Feature Flags**: Enable/disable services using `enable_*` variables
- **Resource Sizing**: Standardized CPU, memory, and storage limits
- **Sensitive Data**: Use Terraform sensitive variables for secrets

## Important Notes

- The repository uses Docker Desktop's local Kubernetes cluster
- All HTTP traffic is automatically redirected to HTTPS
- Cloudflare integration is optional (controlled by `enable_cloudflare` flag)
- Docker socket access is secured through a proxy container
- PostgreSQL service provides shared database functionality
- Docker volumes provide persistent storage with backup/restore capabilities
- All modules follow standardized variable and output patterns
- Feature flags allow selective service deployment