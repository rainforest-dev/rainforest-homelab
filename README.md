# Homelab Infrastructure

A Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and Docker containers. The setup uses Docker Desktop as the local Kubernetes environment with Traefik as the ingress controller and Docker volumes for persistent storage.

## 🏗️ Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications  
- **Traefik**: Ingress controller with automatic HTTPS redirection
- **CoreDNS**: Custom DNS server for automatic domain resolution in Tailscale network
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Services Deployed

#### Kubernetes Services (via Traefik Ingress)
- **Traefik**: Reverse proxy and load balancer with HTTPS
- **CoreDNS**: Custom DNS server for Tailscale integration
- **PostgreSQL**: Database service for applications
- **Open WebUI**: AI chat interface
- **Flowise**: Low-code AI workflow builder  
- **n8n**: Workflow automation platform
- **Homepage**: Service dashboard and portal

#### Docker Containers (Direct Access)
- **Calibre Web**: Ebook server and manager
- **OpenSpeedTest**: Network speed testing tool
- **Docker Proxy**: Secure Docker socket access

## 🚀 Quick Start

### Prerequisites
- Docker Desktop with Kubernetes enabled
- Terraform >= 1.0
- kubectl configured with docker-desktop context

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rainforest-homelab
   ```

2. **Configure environment**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## ⚙️ Configuration

### Environment Variables
Configure your deployment by editing `terraform.tfvars`:

```hcl
# Environment Configuration
environment  = "dev"
project_name = "homelab"

# Infrastructure Configuration
kubernetes_context = "docker-desktop"
domain_suffix      = "rainforest.tools"

# Feature Flags
enable_traefik    = true
enable_postgresql = true
enable_coredns    = true
enable_monitoring = false

# Network Configuration (for Tailscale integration)
tailscale_ip = "100.x.x.x"  # Replace with your actual Tailscale IP

# Resource Sizing
default_cpu_limit    = "500m"
default_memory_limit = "512Mi"
default_storage_size = "10Gi"
```

### Feature Flags
Control which services are deployed:
- `enable_traefik`: Deploy Traefik ingress controller
- `enable_postgresql`: Deploy PostgreSQL database
- `enable_coredns`: Deploy CoreDNS for Tailscale integration
- `enable_monitoring`: Deploy monitoring stack (future)

## 🌐 Service Access

### Kubernetes Services (via Traefik HTTPS)
These services are accessible through Traefik with automatic HTTPS redirection:

- **🏠 https://homepage.rainforest.tools** - Homepage dashboard with all services
- **🌐 https://open-webui.rainforest.tools** - Open WebUI AI chat interface
- **🔄 https://flowise.rainforest.tools** - Flowise AI workflow builder  
- **⚡ https://n8n.rainforest.tools** - n8n automation platform

### 🔗 Tailscale Integration
When CoreDNS is enabled, all `*.rainforest.tools` domains automatically resolve within your Tailscale network:

1. **Automatic DNS Resolution**: CoreDNS resolves `*.rainforest.tools` domains to your Tailscale IP
2. **Secure Remote Access**: Access services from any Tailscale device with HTTPS encryption
3. **No Manual Configuration**: Once Tailscale MagicDNS is configured, all devices automatically resolve domains

**Setup Instructions:**
1. Find your Tailscale IP: `tailscale ip --4`
2. Update `tailscale_ip` in `terraform.tfvars`
3. Configure Tailscale MagicDNS at https://login.tailscale.com/admin/dns:
   - Add nameserver: `[your-tailscale-ip]`
   - Set restricted domains: `rainforest.tools`
4. Access services from any Tailscale device using the HTTPS URLs above

### Docker Containers (Direct HTTP)
These services run as Docker containers with direct port access:

- **📚 http://localhost:8083** - Calibre Web ebook server
- **🚀 http://localhost:3333** - OpenSpeedTest network testing
- **🔧 http://localhost:2375** - Docker Proxy (internal use)

### Management Interfaces
Access administrative interfaces:

- **🎛️ Traefik Dashboard**: Port-forward with `kubectl port-forward -n traefik svc/homelab-traefik 8080:8080` then visit http://localhost:8080
- **🗄️ PostgreSQL**: Access via kubectl (see management section below)

## 🔧 Management

### Terraform Operations
```bash
# Plan infrastructure changes
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
# Check cluster context
kubectl config current-context

# View running services
kubectl get pods -n homelab
kubectl get services -n homelab

# View Traefik dashboard
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=traefik) --namespace=traefik 8080:8080
```

### CoreDNS Operations
```bash
# Check CoreDNS status
kubectl get pods -n homelab -l app.kubernetes.io/name=coredns
kubectl get services -n homelab | grep coredns

# Test DNS resolution
dig @localhost homepage.rainforest.tools
dig @localhost google.com  # Test external forwarding

# View CoreDNS logs
kubectl logs -n homelab -l app.kubernetes.io/name=coredns

# View CoreDNS configuration
kubectl get configmap -n homelab homelab-coredns-coredns -o yaml
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

### PostgreSQL Access
```bash
# Get PostgreSQL password
echo $(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)

# Connect to PostgreSQL
kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace homelab --image docker.io/bitnami/postgresql:15 --env="PGPASSWORD=$(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)" --command -- psql --host homelab-postgresql --username postgres --dbname homelab --port 5432
```

## 📁 Project Structure

```
.
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── versions.tf                # Provider configurations
├── terraform.tfvars          # Environment-specific values
├── terraform.tfvars.example  # Example configuration
├── CLAUDE.md                  # AI assistant guidance
└── modules/
    ├── volume-management/     # Docker volume management
    ├── traefik/              # Traefik ingress controller
    ├── coredns/              # CoreDNS for Tailscale integration
    ├── postgresql/           # PostgreSQL database
    ├── calibre-web/          # Calibre Web ebook server
    ├── open-webui/           # Open WebUI interface
    ├── flowise/              # Flowise AI workflows
    ├── n8n/                  # n8n automation
    ├── homepage/             # Homepage dashboard
    ├── openspeedtest/        # Network speed testing
    └── nfs-persistence/      # NFS storage (disabled)
```

### Module Structure
Each module follows a standardized structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

## 🔒 Security

- **Tailscale Network Isolation**: Services only accessible through encrypted Tailscale network
- **CoreDNS Security**: Minimal privileges, non-root execution, read-only filesystem
- **Docker Socket Proxy**: Secure Docker socket access for containers
- **HTTPS Everywhere**: End-to-end encryption via Tailscale tunnels and Traefik SSL
- **Resource Limits**: CPU and memory limits for all services
- **Volume Management**: Isolated persistent storage with labels
- **Network Policies**: Kubernetes namespace isolation
- **Sensitive Variables**: Tailscale IP marked as sensitive in Terraform

## 🔄 Development

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

### Variable Conventions
All modules use standardized variables:
- `project_name`: Project name for resource naming
- `environment`: Environment (dev/staging/prod)
- `namespace`: Kubernetes namespace
- `cpu_limit` / `memory_limit`: Resource limits
- `enable_persistence`: Enable persistent storage
- `storage_size`: Storage size for persistent volumes

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `terraform plan`
5. Submit a pull request

## 🔒 Security

This repository follows security best practices for infrastructure code. Please review:
- [`SECURITY.md`](SECURITY.md) - Comprehensive security guidelines
- Never commit sensitive data (API keys, passwords, tokens)
- Use `terraform.tfvars.example` as a template for your local configuration

## 📞 Support

For issues and questions:
- Check the `CLAUDE.md` file for AI assistant guidance
- Review Terraform documentation
- Check service-specific documentation in module directories
- For security concerns, see [`SECURITY.md`](SECURITY.md)