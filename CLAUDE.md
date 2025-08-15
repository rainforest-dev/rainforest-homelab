# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and custom manifests. The setup uses Docker Desktop as the local Kubernetes environment with Traefik as the ingress controller and Docker volumes for persistent storage.

## Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications
- **Traefik**: Ingress controller with automatic HTTPS redirection
- **CoreDNS**: Custom DNS server for automatic domain resolution in Tailscale network
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Module Structure
Each service is organized as a Terraform module in `modules/`:
- `traefik/`: Ingress controller with IngressRoute definitions for all services
- `coredns/`: Custom DNS server for automated domain resolution in Tailscale network
- `postgresql/`: Database service for applications that need persistent storage  
- `volume-management/`: Docker volume management for persistent storage
- `nfs-persistence/`: Network storage for persistent volumes (legacy)
- Application modules: `calibre-web/`, `flowise/`, `n8n/`, `open-webui/`, `openspeedtest/`, `homepage/`

### Standardized Module Structure
All modules follow a consistent structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

### Service Architecture
- All services run in the `homelab` namespace (except Traefik in `traefik` namespace)
- Services use configurable domain suffix (configured: `rainforest.tools`)
- Traefik handles SSL termination and routing via IngressRoute CRDs
- CoreDNS provides custom DNS resolution for `*.rainforest.tools` domains to Tailscale network
- Docker proxy container provides secure Docker socket access
- Docker volumes provide managed persistent storage

### DNS Resolution Flow
1. **Client Query**: Device queries `homepage.rainforest.tools`
2. **Tailscale MagicDNS**: Routes to CoreDNS server ([your-tailscale-ip]:53)
3. **CoreDNS**: Resolves `*.rainforest.tools` → Tailscale IP ([your-tailscale-ip])
4. **Traefik**: Routes HTTPS traffic based on Host header to appropriate service
5. **Service**: Returns response through encrypted Tailscale tunnel

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

### CoreDNS Operations
```bash
# Check CoreDNS pod status
kubectl get pods -n homelab -l app.kubernetes.io/name=coredns

# Check CoreDNS service (should be LoadBalancer)
kubectl get services -n homelab | grep coredns

# Test DNS resolution locally
dig @localhost homepage.rainforest.tools
dig @localhost google.com  # Test external forwarding

# View CoreDNS configuration
kubectl get configmap -n homelab homelab-coredns-coredns -o yaml

# View CoreDNS logs
kubectl logs -n homelab -l app.kubernetes.io/name=coredns

# Test DNS from within cluster
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
# Inside the pod: host homepage.rainforest.tools

# Check CoreDNS metrics (if monitoring enabled)
kubectl port-forward -n homelab svc/homelab-coredns-coredns-metrics 9153:9153
# Then visit http://localhost:9153/metrics
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
Services are available at (using `rainforest.tools` domain):

**Kubernetes Services (via Traefik HTTPS):**
- `https://homepage.rainforest.tools` - Homepage dashboard with all services
- `https://open-webui.rainforest.tools` - Open WebUI AI interface  
- `https://flowise.rainforest.tools` - Flowise AI workflows
- `https://n8n.rainforest.tools` - n8n automation platform

**Docker Containers (direct access):**
- `http://localhost:8083` - Calibre Web ebook server
- `http://localhost:3333` - OpenSpeedTest network testing

**Tailscale Integration:**
- All `*.rainforest.tools` domains automatically resolve in Tailscale network
- CoreDNS server accessible at Tailscale IP ([your-tailscale-ip]:53)
- Requires Tailscale MagicDNS configuration: Add nameserver `[your-tailscale-ip]` for domain `rainforest.tools`
- Access services from any Tailscale device without manual DNS configuration

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
5. **Add DNS entry in `modules/coredns/main.tf`** to the hosts plugin configuration
6. For persistent storage, use the `volume-management` module
7. Run `terraform plan` and `terraform apply`

Note: New services automatically get DNS resolution in Tailscale network after step 5

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
    - match: Host(`[service-name].rainforest.tools`)
      kind: Rule
      services:
        - name: [service-name]
          port: [port-number]
```

### CoreDNS Configuration
When adding new services, update the hosts plugin in `modules/coredns/main.tf`:
```hcl
configBlock = join("\n", [
  "${var.tailscale_ip} homepage.rainforest.tools",
  "${var.tailscale_ip} open-webui.rainforest.tools", 
  "${var.tailscale_ip} flowise.rainforest.tools",
  "${var.tailscale_ip} n8n.rainforest.tools",
  "${var.tailscale_ip} [new-service].rainforest.tools",  # Add new service here
  "fallthrough"
])
```

**CoreDNS Features:**
- **Security**: Non-root execution, minimal capabilities, read-only filesystem
- **Performance**: 30s DNS caching, load balancing, up to 1000 concurrent queries
- **Monitoring**: Prometheus metrics on port 9153
- **Reliability**: Health checks, automatic config reload, loop detection
- **Split DNS**: Local domains (*.rainforest.tools) + external forwarding (8.8.8.8)

**Tailscale MagicDNS Setup:**
1. Go to https://login.tailscale.com/admin/dns
2. Add nameserver: `[your-tailscale-ip]`
3. Set restricted domains: `rainforest.tools`
4. All Tailscale devices now automatically resolve `*.rainforest.tools` domains

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
- CoreDNS provides automated DNS resolution for `*.rainforest.tools` domains in Tailscale network
- Tailscale integration enables secure remote access to all services with SSL encryption
- Docker socket access is secured through a proxy container
- PostgreSQL service provides shared database functionality
- Docker volumes provide persistent storage with backup/restore capabilities
- All modules follow standardized variable and output patterns
- Feature flags allow selective service deployment

## Security Considerations

- **Tailscale IP in Configuration**: The `tailscale_ip` variable is marked as sensitive in Terraform to prevent accidental exposure in logs
- **CoreDNS Security**: Runs with minimal privileges, non-root user, and read-only filesystem
- **Network Isolation**: Services only accessible through Tailscale network, not exposed to public internet
- **HTTPS Everywhere**: All traffic encrypted end-to-end through Tailscale tunnels and Traefik SSL termination