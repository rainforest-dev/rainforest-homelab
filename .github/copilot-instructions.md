# Rainforest Homelab Infrastructure

**ALWAYS** reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

Terraform-based homelab infrastructure that deploys self-hosted applications to Docker Desktop Kubernetes with Cloudflare Tunnel for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## Working Effectively

### Bootstrap and Validate Repository

**Install Prerequisites (if missing):**
```bash
# Install Terraform (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Validate Installation:**
```bash
terraform version        # Should show >= 1.0
docker version          # Docker Desktop required
kubectl version --client # kubectl required
ansible --version       # For version management automation
```

**Initialize and Validate Project:**
```bash
# Format and validate Terraform code - takes ~1 second
terraform fmt

# Initialize Terraform - takes ~10 seconds, downloads providers
terraform init

# Validate configuration - takes ~1.3 seconds  
terraform validate
```

**NEVER CANCEL** these operations - they complete quickly but are essential for project functionality.

### Configuration Setup

**Create Environment Configuration:**
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings:
# - domain_suffix: Your Cloudflare-managed domain
# - cloudflare_account_id: From Cloudflare dashboard
# - cloudflare_api_token: From API tokens page (requires Zone:DNS:Edit, Account:Cloudflare Tunnel:Edit permissions)
```

**Required Cloudflare API Token Permissions:**
- Zone:Zone:Read
- Zone:DNS:Edit  
- Account:Cloudflare Tunnel:Edit
- Account:Access:Apps and Policies:Edit

### Deployment Process (2-Step)

**Step 1: Basic Infrastructure Deployment**
```bash
# Plan infrastructure changes - takes ~4 seconds, shows 16+ resources
terraform plan

# Apply changes - takes 2-5 minutes depending on service count
# NEVER CANCEL: Set timeout to 10+ minutes for safety
terraform apply
```

**Step 2: Enable Zero Trust Authentication (Optional)**
1. Enable Cloudflare Access in dashboard (https://dash.cloudflare.com/ → Zero Trust → Settings)
2. Update `terraform.tfvars`:
   ```hcl
   allowed_email_domains = ["yourdomain.com"]  # Your domain
   ```
3. Redeploy:
   ```bash
   terraform plan   # Should show Access application changes
   terraform apply  # Takes 1-2 minutes additional
   ```

### Testing and Validation

**Always validate deployment after changes:**
```bash
# Check Kubernetes cluster connection
kubectl config current-context  # Should show "docker-desktop"

# Verify services are running - takes ~5 seconds
kubectl get pods -n homelab
kubectl get services -n homelab

# Check Cloudflare Tunnel status - takes ~2 seconds
kubectl get pods -n homelab -l app=cloudflared
kubectl logs -n homelab -l app=cloudflared --tail=20

# Verify DNS resolution for your services
dig homepage.yourdomain.com
nslookup open-webui.yourdomain.com 8.8.8.8
```

## Validation Scenarios

**CRITICAL**: After making changes, always test these user scenarios:

### Scenario 1: Service Access Test
1. **Access Homepage Dashboard**: Visit `https://homepage.yourdomain.com`
   - Should load without SSL warnings
   - Should show service links
   - If Zero Trust enabled: Should prompt for email verification

2. **Test Core Services**: Visit each service URL:
   - `https://open-webui.yourdomain.com` - AI chat interface
   - `https://flowise.yourdomain.com` - AI workflow builder
   - `https://n8n.yourdomain.com` - Automation platform

3. **Verify SSL Certificates**: All services should have valid Cloudflare certificates

### Scenario 2: Infrastructure Health Check
```bash
# Verify all pods are running
kubectl get pods -n homelab | grep -v Running || echo "All pods healthy"

# Check tunnel connectivity
kubectl logs -n homelab -l app=cloudflared | grep -i error || echo "Tunnel healthy"

# Test internal service connectivity
kubectl run test-pod --rm -it --restart=Never --image=curlimages/curl -- curl -I http://homelab-homepage.homelab.svc.cluster.local:3000
```

## Version Management and Updates

### Ansible Automation Commands

**Setup Ansible Collections:**
```bash
cd automation
./upgrade setup  # Takes ~3.5 seconds
```

**Check for Updates:**
```bash
cd automation  
./upgrade check  # Takes ~4.7 seconds, shows version comparison table
```

**Generate Upgrade Commands:**
```bash
cd automation
./upgrade manual  # Shows safe upgrade commands for copy-paste
```

**NEVER CANCEL** version checking operations - they complete quickly and provide critical update information.

### Manual Service Updates

**Helm Chart Services** (open-webui, flowise, homepage):
```bash
# Update version in main.tf, then:
terraform plan -target="module.service-name"
terraform apply -target="module.service-name"
```

**OCI Services** (postgresql, n8n):
```bash
# Check for new versions manually, update chart_version in main.tf
terraform plan -target="module.postgresql"
terraform apply -target="module.postgresql"  
```

**Docker Services** (calibre-web):
```bash
# Force container recreation to pull latest
terraform apply -replace="module.calibre-web.docker_container.calibre-web"
```

## Key Architecture Components

### Core Infrastructure
- **Terraform**: Infrastructure as Code (16+ modules, 6 providers)
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Cloudflare Tunnel**: Secure external access with SSL certificates
- **Helm Charts**: Kubernetes application packaging
- **Docker Volumes**: Persistent storage for applications

### Service Categories
**Kubernetes Services** (via Cloudflare Tunnel):
- cloudflared, postgresql, minio, open-webui, flowise, n8n, homepage

**Docker Containers** (direct access):
- calibre-web, openspeedtest, dockerproxy

### Network Flow
```
Internet → Cloudflare Edge → Tunnel → cloudflared pods → K8s Services
```

### Security Features
- **Hidden Home IP**: Tunnel provides outbound-only connectivity
- **Automatic SSL**: Real Cloudflare certificates for all services
- **Zero Trust Ready**: Optional email authentication
- **DDoS Protection**: Enterprise-grade via Cloudflare
- **Docker Socket Proxy**: Secure container management

## Common Operations

### Terraform Commands
```bash
# Quick validation cycle - takes ~15 seconds total
terraform fmt && terraform validate && terraform plan

# Full deployment - takes 2-5 minutes  
# NEVER CANCEL: Set timeout to 10+ minutes
terraform apply

# Destroy infrastructure - takes 1-3 minutes
# NEVER CANCEL: Set timeout to 10+ minutes  
terraform destroy

# Target specific modules - takes 30 seconds to 2 minutes
terraform apply -target="module.service-name"
```

### Docker Volume Management
```bash
# List project volumes
docker volume ls --filter label=project=homelab

# Backup a volume  
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar czf /backup/calibre-config-backup.tar.gz -C /data .

# Restore a volume
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar xzf /backup/calibre-config-backup.tar.gz -C /data
```

### PostgreSQL Access
```bash
# Get database password
echo $(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)

# Connect to database
kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace homelab --image docker.io/bitnami/postgresql:15 --env="PGPASSWORD=$(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)" --command -- psql --host homelab-postgresql --username postgres --dbname homelab --port 5432
```

### MinIO Object Storage
```bash
# Get MinIO credentials
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-user}" | base64 --decode; echo
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-password}" | base64 --decode; echo

# Access: https://minio.yourdomain.com (console)
# S3 API: https://s3.yourdomain.com (applications)
```

## Service Development Patterns

### Adding New Services

**ALWAYS follow this exact sequence:**

1. **Create Module Directory:**
   ```bash
   mkdir -p modules/service-name
   cd modules/service-name
   ```

2. **Create Standard Module Files:**
   - `main.tf`: Helm release or Docker container
   - `variables.tf`: Standard variables (project_name, environment, cpu_limit, memory_limit, storage_size, enable_persistence)
   - `outputs.tf`: Include service_url output
   - `versions.tf`: Provider constraints if needed

3. **Add Service to main.tf:**
   ```hcl
   module "service-name" {
     source = "./modules/service-name"
     
     project_name       = var.project_name
     environment        = var.environment
     cpu_limit          = var.default_cpu_limit
     memory_limit       = var.default_memory_limit
     enable_persistence = var.enable_persistence
     storage_size       = var.default_storage_size
   }
   ```

4. **Update Cloudflare Tunnel Configuration** in `modules/cloudflare-tunnel/main.tf`:
   - Add to `dynamic "ingress_rule"` services variable
   - Add to DNS records `for_each` list  
   - Add to Zero Trust applications if authentication needed

5. **Validate and Deploy:**
   ```bash
   terraform fmt
   terraform validate
   terraform plan
   terraform apply
   ```

### Module Standardization

**All modules MUST use these standard variables:**
```hcl
variable "project_name" { type = string }
variable "environment" { type = string }  
variable "namespace" { type = string default = "homelab" }
variable "cpu_limit" { type = string }
variable "memory_limit" { type = string }
variable "storage_size" { type = string }
variable "enable_persistence" { type = bool }
```

**All modules MUST provide these outputs:**
```hcl
output "resource_id" { value = ... }
output "service_url" { value = ... }
output "service_name" { value = ... }
output "namespace" { value = ... }
```

## Common Issues and Solutions

### Terraform Issues
- **"Module not installed"**: Run `terraform init`
- **Provider download fails**: Check internet connectivity, retry `terraform init`
- **Plan shows unexpected changes**: Check if terraform.tfvars matches requirements

### Kubernetes Issues  
- **kubectl context wrong**: Run `kubectl config use-context docker-desktop`
- **Pods not starting**: Check `kubectl describe pod -n homelab <pod-name>`
- **Services unreachable**: Verify `kubectl get services -n homelab`

### Cloudflare Issues
- **Tunnel not connecting**: Check API token permissions and account ID
- **DNS not resolving**: Verify domain is managed by Cloudflare
- **SSL errors**: Wait 5-10 minutes for certificate propagation

### Docker Issues
- **Volume mount fails**: Ensure Docker Desktop has file system access
- **Container won't start**: Check `docker logs <container-name>`

## Build and Test Timing Expectations

**NEVER CANCEL these operations - all complete within expected timeframes:**

- `terraform fmt`: < 1 second
- `terraform validate`: ~1.3 seconds  
- `terraform init`: ~10 seconds (with provider downloads)
- `terraform plan`: ~4 seconds
- `terraform apply`: 2-5 minutes (NEVER CANCEL - set 10+ minute timeout)
- `./upgrade check`: ~4.7 seconds
- `kubectl` commands: 1-5 seconds

**Long-running operations require explicit timeouts:**
- Infrastructure deployment: 10+ minutes timeout
- Service health checks: 5+ minutes timeout
- Volume operations: 5+ minutes timeout

## CI/CD Integration

**Always run these validation steps before committing:**
```bash
# Format and validate
terraform fmt
terraform validate

# Quick plan check (will fail without credentials, but syntax should be valid)
terraform plan -input=false || echo "Expected to fail without credentials"

# Ansible collection check
cd automation && ./upgrade setup
```

**GitHub Actions Integration:**
- `.github/workflows/claude.yml`: Claude Code automation
- `.github/workflows/claude-code-review.yml`: Automated PR reviews

## Important File Locations

### Configuration Files
- `terraform.tfvars`: Environment-specific configuration (not committed)
- `terraform.tfvars.example`: Template for configuration
- `versions.tf`: Provider version constraints
- `main.tf`: Root module with all service definitions

### Key Modules
- `modules/cloudflare-tunnel/`: External access and SSL termination
- `modules/volume-management/`: Persistent storage management
- `modules/postgresql/`: Shared database service
- `modules/minio/`: S3-compatible object storage

### Automation
- `automation/upgrade`: Version management script
- `automation/upgrade.yml`: Ansible playbook for updates
- `automation/UPGRADE_SOP.md`: Detailed upgrade procedures

### Documentation
- `README.md`: User-focused documentation
- `CLAUDE.md`: AI assistant guidance
- `SECURITY.md`: Security guidelines

## Critical Security Considerations

- **NEVER** commit `terraform.tfvars` - contains sensitive credentials
- **ALWAYS** use `terraform.tfvars.example` as template
- **VERIFY** Cloudflare API token has minimal required permissions
- **ENABLE** Zero Trust authentication for production environments
- **REVIEW** Docker socket access requirements for MCP Gateway
- **MONITOR** Cloudflare Analytics for suspicious access patterns

## Quick Reference Commands

```bash
# Essential validation cycle
terraform fmt && terraform validate && terraform plan

# Full deployment 
terraform apply  # NEVER CANCEL - 2-5 minutes

# Check system health
kubectl get pods -n homelab
kubectl logs -n homelab -l app=cloudflared --tail=10

# Version management
cd automation && ./upgrade check

# Access services
curl -I https://homepage.yourdomain.com
```

**Remember**: This homelab prioritizes security through Cloudflare Tunnel over traditional port forwarding, providing enterprise-grade SSL certificates and optional Zero Trust authentication while keeping your home IP completely hidden.
