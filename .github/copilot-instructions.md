# Rainforest Homelab Infrastructure

**ALWAYS** reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

Terraform-based homelab infrastructure that deploys self-hosted applications to Docker Desktop Kubernetes with Cloudflare Tunnel for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## Core Architecture Principles

### Dual Deployment Model

This project uses **TWO deployment models** (understand this deeply to avoid confusion):

1. **Kubernetes Services** (via Helm): PostgreSQL, MinIO, Open WebUI, Flowise, n8n, Homepage
   - Deployed via `helm_release` resources in modules
   - Access via Kubernetes services (`*.homelab.svc.cluster.local`)
   - External access via Cloudflare Tunnel
2. **Docker Containers** (direct Docker): Calibre Web, Whisper STT, Docker MCP Gateway, dockerproxy
   - Deployed via `docker_container` resources
   - Access via `host.docker.internal` (Docker Desktop networking)
   - Still exposed through Cloudflare Tunnel

**Key Insight**: Services like Open WebUI can use EITHER model (see `deployment_type` variable). When troubleshooting, always check which model is active.

### The Services-First Pattern

All service configuration is centralized in `locals.tf` → `local.services` map, which drives:

- Cloudflare Tunnel ingress rules (`modules/cloudflare-tunnel/main.tf`)
- DNS record creation (CNAME records)
- Zero Trust application policies (when `enable_auth = true` and `allowed_email_domains` configured)

**Adding a service requires 4 synchronized updates:**

1. Module definition in `main.tf`
2. Service entry in `locals.tf` services map
3. Cloudflare Tunnel automatically picks it up (no manual editing)
4. DNS record automatically created (unless `internal = true`)

### Database Self-Registration Pattern

Services don't manually create databases. Instead, they use the `database-init` module:

```hcl
module "flowise_database" {
  source = "./modules/database-init"

  service_name         = "flowise"
  database_name        = "flowise_db"
  service_user         = "flowise_user"
  service_password     = random_password.flowise_password.result
  postgres_secret_name = module.postgresql[0].postgresql_secret_name
  force_recreate       = "2"  # Increment to force recreation
}
```

**Critical**: The `database-init` module creates a Kubernetes Job that:

- Waits for PostgreSQL readiness (30 retries × 5s)
- Creates database if not exists
- Creates service-specific user with grants
- Runs custom initialization SQL
- Uses `force_recreate` to trigger recreation (increment when schema changes)

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

## Critical Project-Specific Patterns

### External Storage Strategy (macOS Optimization)

This homelab uses **external storage** to avoid Docker Desktop's slow APFS volumes:

```hcl
external_storage_path = "/Volumes/Samsung T7 Touch/homelab-data"
```

**Where this matters:**

- PostgreSQL: Uses `kubernetes_persistent_volume` with `host_path` pointing to external storage
- n8n: Uses `use_external_storage = true` for direct volume mounts
- Calibre Web: Uses `use_external_storage = true`

**Module Pattern**: When `use_external_storage = true`, modules use `null_resource` to create directories then mount via `host_path`.

### Cloudflare Tunnel Architecture (Critical)

The tunnel module is the **single source of truth** for external access:

```hcl
# In modules/cloudflare-tunnel/main.tf:
dynamic "ingress_rule" {
  for_each = var.services
  content {
    hostname = "${ingress_rule.value.hostname}.${var.domain_suffix}"
    service  = ingress_rule.value.service_url  # Points to K8s/Docker service
  }
}
```

**Service URL Formats:**

- Kubernetes: `http://service-name.homelab.svc.cluster.local:port`
- Docker: `http://host.docker.internal:port`

**Internal Services Pattern**: OAuth Worker is marked `internal = true` in `locals.tf` to skip DNS creation (manages its own domain via `cloudflare_workers_domain`).

### OAuth Worker Pattern (Docker MCP Gateway)

When `oauth_client_id` is configured, the system deploys TWO components:

1. **Docker MCP Gateway** (`modules/docker-mcp-gateway`): Core MCP server

   - Runs as Docker container with socket access
   - Internal endpoint: `http://host.docker.internal:3100`
   - Tunnel endpoint: `docker-mcp-internal.domain.com` (no auth)

2. **OAuth Worker** (`modules/oauth-worker`): Cloudflare Worker authentication proxy
   - Intercepts requests to `docker-mcp.domain.com`
   - Performs OAuth flow with Cloudflare Access
   - Stores sessions in KV namespace
   - Proxies authenticated requests to gateway

**Deployment sequence matters**: OAuth Worker `depends_on = [module.docker_mcp_gateway]`

### Version Management via Ansible

The project uses Ansible for version tracking, NOT for deployment:

```bash
cd automation
./upgrade check   # Shows current vs latest versions in table format
./upgrade manual  # Generates Terraform commands for upgrades
```

**Important**: Ansible does NOT apply upgrades. It generates safe `terraform apply -target` commands for manual execution. This prevents accidental breaking changes.

**Chart Version Sources:**

- Helm repos: Searched via `helm search repo`
- OCI registries (PostgreSQL, n8n): "MANUAL_CHECK" status
- Docker images: Always "PULL_LATEST"

### Module Standardization Contract

ALL service modules MUST implement this interface:

**Required Variables:**

```hcl
variable "project_name" { type = string }
variable "environment" { type = string }
variable "cpu_limit" { type = string }
variable "memory_limit" { type = string }
variable "enable_persistence" { type = bool }
variable "storage_size" { type = string }
```

**Required Outputs:**

```hcl
output "service_url" { value = "..." }  # For Cloudflare Tunnel
output "service_name" { value = "..." }
output "namespace" { value = "..." }
```

**Why this matters**: Root `main.tf` passes standard variables to all modules. Breaking this contract breaks the deployment.

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

### Adding New Services (Complete Workflow)

**CRITICAL**: The services-first pattern means you update `locals.tf` FIRST, then everything else flows from there.

**Step 1: Add to locals.tf services map**

```hcl
locals {
  services = merge(
    # ... existing services ...

    var.enable_my_service ? {
      "my-service" = {
        hostname    = "my-service"
        service_url = "http://my-service.homelab.svc.cluster.local:8080"
        enable_auth = true     # Require Zero Trust auth
        type        = "kubernetes"  # or "docker"
        internal    = false    # Set true to skip DNS creation
      }
    } : {},
  )
}
```

**Step 2: Create module structure**

```bash
mkdir -p modules/my-service
cd modules/my-service
```

**Create `variables.tf`** (MUST follow standardization contract):

```hcl
variable "project_name" { type = string }
variable "environment" { type = string }
variable "namespace" { type = string; default = "homelab" }
variable "cpu_limit" { type = string }
variable "memory_limit" { type = string }
variable "storage_size" { type = string }
variable "enable_persistence" { type = bool }
```

**Create `outputs.tf`** (MUST include service_url):

```hcl
output "service_url" {
  value = "http://my-service.homelab.svc.cluster.local:8080"
}
output "service_name" { value = "my-service" }
output "namespace" { value = var.namespace }
```

**Step 3: Add to root main.tf**

```hcl
module "my_service" {
  source = "./modules/my-service"
  count  = var.enable_my_service ? 1 : 0

  project_name       = var.project_name
  environment        = var.environment
  cpu_limit          = var.default_cpu_limit
  memory_limit       = var.default_memory_limit
  enable_persistence = var.enable_persistence
  storage_size       = var.default_storage_size
}
```

**Step 4: Add feature flag to variables.tf**

```hcl
variable "enable_my_service" {
  description = "Enable My Service"
  type        = bool
  default     = true
}
```

**Step 5: Cloudflare Tunnel automatically picks it up** - No manual editing needed! The `dynamic "ingress_rule"` in `modules/cloudflare-tunnel/main.tf` reads from `local.services`.

**Step 6: Validate and deploy**

```bash
terraform fmt && terraform validate && terraform plan
terraform apply
```

### Database-Connected Services Pattern

If your service needs PostgreSQL:

**Step 1: Create password in main.tf**

```hcl
resource "random_password" "my_service_password" {
  length  = 24
  special = true
}
```

**Step 2: Create database-init module**

```hcl
module "my_service_database" {
  count  = length(module.postgresql) > 0 ? 1 : 0
  source = "./modules/database-init"

  service_name          = "my-service"
  database_name         = "my_service_db"
  service_user          = "my_service_user"
  service_password      = random_password.my_service_password.result
  postgres_secret_name  = module.postgresql[0].postgresql_secret_name
  force_recreate        = "1"  # Increment to force recreation

  depends_on = [module.postgresql]
}
```

**Step 3: Pass database config to service module**

```hcl
module "my_service" {
  # ... standard config ...

  database_host        = module.postgresql[0].postgresql_host
  database_name        = "my_service_db"
  database_user        = "my_service_user"
  database_secret_name = module.postgresql[0].postgresql_secret_name

  depends_on = [module.my_service_database]
}
```

**Critical dependency order**: `postgresql` → `database-init` → `service`

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
