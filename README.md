# Homelab Infrastructure

A Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and Docker containers. The setup uses Docker Desktop as the local Kubernetes environment with **Cloudflare Tunnel** for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## 🏗️ Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications  
- **Cloudflare Tunnel**: Secure external access with automatic SSL certificates
- **cloudflared**: Tunnel client running in Kubernetes for secure connectivity
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Network Architecture
```
Internet → Cloudflare Edge → Cloudflare Tunnel → cloudflared pods → Kubernetes Services
```

- **No exposed ports**: Your home IP stays completely hidden
- **Automatic SSL**: Real certificates from Cloudflare 
- **Zero Trust**: Optional email authentication for services
- **Global CDN**: Fast access from anywhere via Cloudflare's network

### Services Deployed

#### Kubernetes Services (via Cloudflare Tunnel)
- **cloudflared**: Tunnel client for secure connectivity
- **PostgreSQL**: Database service for applications
- **MinIO**: S3-compatible object storage for files and backups
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
- **Docker Desktop** with Kubernetes enabled
- **Terraform** >= 1.0
- **kubectl** configured with docker-desktop context
- **Domain** managed by Cloudflare
- **Cloudflare account** (free tier supported)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rainforest-homelab
   ```

2. **Get Cloudflare credentials**
   
   **API Token** (https://dash.cloudflare.com/profile/api-tokens):
   - Click "Create Token" → "Custom token"
   - Permissions: `Zone:Zone:Read`, `Zone:DNS:Edit`, `Account:Cloudflare Tunnel:Edit`, `Account:Access: Apps and Policies:Edit`
   - Zone Resources: Include your domain
   - Account Resources: Include your account
   
   **Account ID**: 
   - Go to your domain dashboard
   - Copy "Account ID" from right sidebar

3. **Configure environment**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Cloudflare credentials and domain
   ```

4. **Deploy infrastructure (2-step process)**
   
   **Step 1: Basic tunnel setup**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   
   **Step 2: Enable Zero Trust authentication (optional)**
   - Go to https://dash.cloudflare.com/ → Zero Trust → Settings
   - Enable "Access" (requires billing info, but Zero Trust is free for up to 50 users)
   - Update `terraform.tfvars` with your allowed email domains:
     ```hcl
     allowed_email_domains = ["gmail.com"]  # or your company domain
     ```
   - Deploy authentication:
     ```bash
     terraform plan
     terraform apply
     ```

5. **Access your services**
   - Services will be available at `https://service-name.yourdomain.com`
   - DNS records and SSL certificates are automatically created
   - With Zero Trust: Services require email verification before access

## ⚙️ Configuration

### Required Configuration
Configure your deployment by editing `terraform.tfvars`:

```hcl
# Environment Configuration
environment  = "dev"
project_name = "homelab"

# Infrastructure Configuration
kubernetes_context = "docker-desktop"
domain_suffix      = "yourdomain.com"  # Your Cloudflare-managed domain

# Cloudflare Configuration (REQUIRED)
cloudflare_account_id = "your-account-id"     # From Cloudflare dashboard
cloudflare_api_token  = "your-api-token"      # From API tokens page

# Feature Flags
enable_cloudflare_tunnel = true   # Enable Cloudflare Tunnel
enable_postgresql        = true   # Deploy PostgreSQL database

# Zero Trust Authentication (OPTIONAL)
allowed_email_domains = ["gmail.com"]           # Email domains for access
allowed_emails        = ["user@example.com"]    # Specific emails for access

# Resource Sizing
default_cpu_limit    = "500m"
default_memory_limit = "1Gi"
default_storage_size = "10Gi"
```

### Feature Flags
Control which services are deployed:
- `enable_cloudflare_tunnel`: Enable Cloudflare Tunnel for external access
- `enable_postgresql`: Deploy PostgreSQL database
- `enable_minio`: Deploy MinIO S3-compatible object storage
- `enable_docker_mcp_gateway`: Deploy Docker MCP Gateway for remote Docker operations
- `enable_coredns`: Legacy Tailscale integration (disabled when using tunnel)
- `enable_traefik`: Legacy ingress controller (disabled when using tunnel)

### Zero Trust Authentication (2-Step Deployment)

**Step 1: Basic deployment** (no authentication)
- Deploy with empty `allowed_email_domains = []`
- Services are publicly accessible via HTTPS

**Step 2: Enable authentication** (optional but recommended)
1. **Enable Cloudflare Access** at https://dash.cloudflare.com/ → Zero Trust → Settings
   - Requires adding billing info (Zero Trust is free for up to 50 users)
2. **Configure email domains** in `terraform.tfvars`:
   ```hcl
   allowed_email_domains = ["gmail.com"]  # Allow any Gmail addresses
   allowed_emails        = []             # Or specific emails: ["user@company.com"]
   ```
3. **Redeploy authentication**: `terraform apply`

## 🌐 Service Access

### Kubernetes Services (via Cloudflare Tunnel)
These services are accessible globally with automatic HTTPS certificates:

- **🏠 https://homepage.yourdomain.com** - Homepage dashboard with all services
- **🌐 https://open-webui.yourdomain.com** - Open WebUI AI chat interface
- **🔄 https://flowise.yourdomain.com** - Flowise AI workflow builder  
- **⚡ https://n8n.yourdomain.com** - n8n automation platform
- **🐳 https://docker-mcp.yourdomain.com** - Docker MCP Gateway for remote Docker operations (optional)

### 🔒 Security Features
- **Real SSL Certificates**: Automatic and trusted certificates from Cloudflare
- **Hidden Home IP**: Your public IP is never exposed 
- **Global CDN**: Fast access from anywhere via Cloudflare's network
- **DDoS Protection**: Enterprise-grade protection included
- **Zero Trust Ready**: Optional email authentication

### 🌍 Access from Anywhere
- **No VPN required**: Services accessible from any internet connection
- **Mobile friendly**: Works on phones, tablets, laptops
- **Office networks**: Bypasses most corporate firewalls
- **Travel friendly**: Same URLs work globally

### Docker Containers (Direct HTTP)
These services run as Docker containers with direct port access:

- **📚 http://localhost:8083** - Calibre Web ebook server
- **🚀 http://localhost:3333** - OpenSpeedTest network testing
- **🔧 http://localhost:2375** - Docker Proxy (internal use)

## 🐳 Docker MCP Gateway

The Docker MCP Gateway provides **remote Docker operations** via the Model Context Protocol (MCP), enabling secure container management from anywhere.

### Features
- **Remote Docker Control**: Manage containers from any MCP-compatible client
- **OAuth Authentication**: Secure access with Cloudflare Zero Trust
- **132+ Tools**: Includes GitHub, Terraform, Obsidian, Playwright, and Sequential Thinking tools
- **Multiple Transports**: SSE and HTTP streaming support
- **Claude Compatible**: Works with Claude web, desktop, and mobile apps

### Usage
1. **OAuth-Protected (Recommended)**: `https://docker-mcp.rainforest.tools/sse`
2. **Local Development**: `http://localhost:3100/sse` (bypasses authentication)

### OAuth Setup for Docker MCP Gateway (Terraform Approach)

**⚠️ RECOMMENDED:** Use Terraform for automated OAuth Worker deployment with centralized configuration management.

#### Terraform Deployment (Recommended)

1. **Add OAuth Configuration** to your `terraform.tfvars`:
   ```hcl
   # OAuth Configuration for Docker MCP Gateway
   cloudflare_team_name  = "your-team-name"      # e.g., "rainforest"
   oauth_client_id       = "your-client-id"      # From Cloudflare Access SaaS app
   oauth_client_secret   = "your-client-secret"  # From Cloudflare Access SaaS app
   ```

2. **Update API Token Permissions** (if needed):
   Your Cloudflare API token needs **Cloudflare Workers:Edit** permissions for KV and Worker management:
   - Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
   - Edit your existing token or create a new one
   - Add permissions: **Cloudflare Workers:Edit**, **Zone:Edit**, **Account:Read**

3. **Deploy via Terraform**:
   ```bash
   terraform plan
   terraform apply
   ```

   This automatically:
   - Creates KV namespace for session storage
   - Deploys OAuth Worker with all environment variables
   - Sets up custom domain `docker-mcp.yourdomain.com`
   - Manages configuration through Infrastructure as Code

4. **Access OAuth-protected endpoint**: `https://docker-mcp.yourdomain.com/sse`

#### Manual Setup (Deprecated)
<details>
<summary>🚫 Legacy Manual Setup (Click to expand - Not recommended)</summary>

**Note**: Manual setup is deprecated in favor of the Terraform approach above for better configuration management and consistency.

1. **Create Cloudflare Access SaaS Application**:
   - Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Access** → **Applications**
   - Click **Add application** → **SaaS**
   - Configure with redirect URI: `https://docker-mcp.yourdomain.com/callback`
   - Copy Client ID and Client Secret

2. **Manually Deploy Worker**: Use Cloudflare Workers dashboard with manual environment variable configuration

</details>

#### OAuth Worker Architecture

The Terraform deployment automatically creates and configures:

**📁 Worker Code**: `workers/oauth-gateway.js` (KV-enabled OAuth proxy)  
**🏗️ Infrastructure**: 
- `modules/oauth-worker/` - Terraform module for OAuth Worker
- KV namespace for session storage  
- Custom domain configuration
- Environment variable management

**🔧 Features**:
- **Session Management**: Secure server-side sessions in Cloudflare KV
- **OAuth Flow**: Complete OAuth 2.1 implementation with Cloudflare Access
- **Request Proxying**: Transparent forwarding to Docker MCP Gateway
- **Security**: User authentication, session validation, and audit logging

#### Usage After Terraform Deployment

- **OAuth-Protected URL**: `https://docker-mcp.yourdomain.com/sse`
- **Authentication**: Automatic OAuth flow with Cloudflare Access
- **Configuration**: Centrally managed via `terraform.tfvars`

### Internal Security Architecture (Service Tokens)

The Docker MCP Gateway uses a **multi-layer security architecture** with Cloudflare Access Service Tokens:

```
Client → GitHub OAuth → docker-mcp.rainforest.tools (Public)
           ↓ Service Token Headers
         docker-mcp-internal.rainforest.tools (Protected)
           ↓ Cloudflare Tunnel
         host.docker.internal:3100 (Docker MCP Gateway)
```

**Security Layers:**
1. **Public Endpoint** (`docker-mcp.rainforest.tools`):
   - GitHub OAuth authentication for end users
   - OAuth Worker validates user identity

2. **Internal Endpoint** (`docker-mcp-internal.rainforest.tools`):
   - Protected by Zero Trust service token authentication
   - DNS record exists (required for Worker-to-Worker communication)
   - Only accessible with valid service token headers
   - Blocks all public internet access

3. **Network Isolation**:
   - Docker MCP Gateway only reachable via Cloudflare Tunnel
   - No direct internet exposure

**Service Token Setup** (One-Time):

1. **Create Service Token**:
   ```bash
   # Navigate to: https://dash.cloudflare.com/ → Zero Trust → Access → Service Auth → Service Tokens
   # Click "Create Service Token"
   # Name: "OAuth Worker - Docker MCP Internal"
   # Copy Client ID and Client Secret immediately
   ```

2. **Configure Terraform** (`terraform.tfvars`):
   ```hcl
   service_token_ids = ["your-client-id.access"]
   oauth_worker_service_token_client_id = "your-client-id.access"
   oauth_worker_service_token_client_secret = "your-client-secret"
   ```

3. **Deploy Infrastructure**:
   ```bash
   terraform apply  # Creates DNS, Access Application, and Worker secrets
   ```

4. **Create Access Policy** (Manual - Cloudflare API limitation):
   - Go to: Zero Trust → Access → Applications → "Docker-Mcp-Internal - homelab"
   - Policies → Add policy → Action: "Service Auth"
   - Include → Service Token → Select your token
   - Save policy

**Why This Architecture?**
- **Zero Trust**: Internal endpoint requires service token authentication
- **Defense in Depth**: Multiple security layers (OAuth + Service Token + Network Isolation)
- **Credential Isolation**: Service tokens created manually (not in Terraform state)
- **Automatic Secret Management**: Terraform configures Worker secrets from terraform.tfvars

See `CLAUDE.md` for complete service token setup guide.

### Security Considerations

⚠️ **Docker Socket Access**: The Docker MCP Gateway requires Docker socket access, providing significant privileges:
- Container management capabilities
- Image operations (pull, build, push)
- Potential host filesystem access
- Privilege escalation possibilities

**Security Mitigations**:
- Deploy only in trusted environments
- Use OAuth authentication (see setup above)
- Monitor container activities via logs
- Network isolation via Docker networks
- Resource limits and health checks

### Management Interfaces
Access administrative interfaces:

- **☁️ Cloudflare Dashboard**: https://dash.cloudflare.com/
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

# Check cloudflared tunnel status
kubectl get pods -n homelab -l app=cloudflared
kubectl logs -n homelab -l app=cloudflared

# View tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml
```

### Cloudflare Tunnel Operations
```bash
# Check tunnel connectivity
kubectl logs -n homelab -l app=cloudflared --tail=20

# Test service connectivity (internal)
kubectl run test-pod --rm -it --restart=Never --image=curlimages/curl -- curl -I http://homelab-homepage.homelab.svc.cluster.local:3000

# View tunnel metrics (if enabled)
kubectl port-forward -n homelab -l app=cloudflared 2000:2000
# Then visit http://localhost:2000/metrics
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

### MinIO Object Storage Access

**Web Console**: Access via `https://minio.yourdomain.com` (configured in Cloudflare Tunnel)

**S3 API Endpoint**: Access via `https://s3.yourdomain.com` for S3-compatible applications

```bash
# Get MinIO credentials
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-user}" | base64 --decode; echo
kubectl get secret --namespace homelab homelab-minio -o jsonpath="{.data.root-password}" | base64 --decode; echo

# MinIO client configuration (mc)
mc alias set homelab https://s3.yourdomain.com <access-key> <secret-key>

# Create a bucket
mc mb homelab/my-bucket

# Upload files
mc cp /path/to/file homelab/my-bucket/

# List buckets
mc ls homelab/
```

**For Applications**: Use S3-compatible SDKs with:
- **Endpoint**: `https://s3.yourdomain.com`
- **Access Key**: Retrieved from Kubernetes secret
- **Secret Key**: Retrieved from Kubernetes secret
- **Region**: `us-east-1` (default)

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
    ├── cloudflare-tunnel/     # Cloudflare Tunnel for external access
    ├── postgresql/           # PostgreSQL database
    ├── minio/                # MinIO S3-compatible object storage
    ├── calibre-web/          # Calibre Web ebook server
    ├── open-webui/           # Open WebUI interface
    ├── flowise/              # Flowise AI workflows
    ├── n8n/                  # n8n automation
    ├── homepage/             # Homepage dashboard
    ├── openspeedtest/        # Network speed testing
    ├── traefik/              # Legacy Traefik ingress (disabled)
    ├── coredns/              # Legacy CoreDNS (disabled)
    └── nfs-persistence/      # NFS storage (disabled)
```

### Module Structure
Each module follows a standardized structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

## 🔒 Security

- **Cloudflare Tunnel**: Zero trust network access with hidden home IP
- **Automatic SSL**: Real certificates from Cloudflare with perfect forward secrecy
- **DDoS Protection**: Enterprise-grade protection via Cloudflare's global network
- **Zero Trust Ready**: Email-based authentication for sensitive services
- **Docker Socket Proxy**: Secure Docker socket access for containers
- **Resource Limits**: CPU and memory limits for all services
- **Volume Management**: Isolated persistent storage with labels
- **Network Policies**: Kubernetes namespace isolation
- **Credential Security**: API tokens and secrets encrypted in Kubernetes

## 🔄 Development

### Adding New Services
1. Create new module directory in `modules/[service-name]/`
2. Create standardized module files:
   - `main.tf`: Main resource definitions
   - `variables.tf`: Standard variables (project_name, environment, etc.)
   - `outputs.tf`: Resource outputs including service_url
   - `versions.tf`: Provider constraints (if needed)
3. Add service to main `main.tf` as a module with standard variables
4. **Add ingress rule in `modules/cloudflare-tunnel/main.tf`** to the tunnel configuration
5. **Add DNS record in `modules/cloudflare-tunnel/main.tf`** to the services list
6. **Add Zero Trust app in `modules/cloudflare-tunnel/main.tf`** for authentication (optional)
7. For persistent storage, use the `volume-management` module
8. Run `terraform plan` and `terraform apply`

Note: New services automatically get SSL certificates and DNS records via Cloudflare

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