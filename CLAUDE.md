# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and custom manifests. The setup uses Docker Desktop as the local Kubernetes environment with **Cloudflare Tunnel** for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications
- **Cloudflare Tunnel**: Secure external access with automatic SSL certificates
- **cloudflared**: Tunnel client running in Kubernetes for secure connectivity
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Module Structure
Each service is organized as a Terraform module in `modules/`:
- `cloudflare-tunnel/`: Cloudflare Tunnel for secure external access with SSL certificates
- `postgresql/`: Database service for applications that need persistent storage
- `volume-management/`: Docker volume management for persistent storage
- Application modules: `calibre-web/`, `flowise/`, `n8n/`, `open-webui/`, `homepage/`, `whisper/`
- AI/ML services: `whisper/` (Speech-to-Text API using faster-whisper)
- External services: `openspeedtest/` (moved to Raspberry Pi)
- Legacy modules: `traefik/` (removed - replaced by pure Cloudflare Tunnel), `coredns/` (DNS - replaced by Cloudflare), `nfs-persistence/` (storage)

### Standardized Module Structure
All modules follow a consistent structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

### Service Architecture
- All services run in the `homelab` namespace 
- Services use configurable domain suffix (example: `rainforest.tools`)
- Cloudflare Tunnel handles SSL termination and routing via tunnel configuration
- cloudflared pods provide secure connectivity between Cloudflare Edge and Kubernetes services
- Docker proxy container provides secure Docker socket access
- Docker volumes provide managed persistent storage

### Cloudflare Tunnel Flow
1. **Client Request**: Device queries `homepage.yourdomain.com`
2. **Cloudflare DNS**: Resolves to Cloudflare Edge servers
3. **Cloudflare Edge**: Routes to your Cloudflare Tunnel
4. **cloudflared pods**: Receive tunnel traffic and route to Kubernetes services
5. **Service Response**: Returns through encrypted tunnel with automatic SSL

## Common Commands

### Terraform Operations (2-Step Deployment)

**Step 1: Basic Cloudflare Tunnel setup**
```bash
# Initialize and deploy basic tunnel (no authentication)
terraform init
terraform plan
terraform apply
```

**Step 2: Enable Zero Trust authentication (optional)**
```bash
# After enabling Access in Cloudflare dashboard and configuring allowed_email_domains
terraform plan
terraform apply
```

**General operations**
```bash
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

# Check cloudflared tunnel status  
kubectl get pods -n homelab -l app=cloudflared
kubectl logs -n homelab -l app=cloudflared

# Get PostgreSQL password
echo $(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Cloudflare Tunnel Operations
```bash
# Check tunnel connectivity
kubectl logs -n homelab -l app=cloudflared --tail=20

# View tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml

# Test internal service connectivity
kubectl run test-pod --rm -it --restart=Never --image=curlimages/curl -- curl -I http://homelab-homepage.homelab.svc.cluster.local:3000

# Check tunnel credentials
kubectl get secret -n homelab cloudflare-tunnel-credentials

# View tunnel metrics (if enabled)
kubectl port-forward -n homelab -l app=cloudflared 2000:2000
# Then visit http://localhost:2000/metrics

# Test external DNS resolution
dig homepage.yourdomain.com
nslookup homepage.yourdomain.com 8.8.8.8
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

**All Services (via Cloudflare Tunnel with HTTPS):**
- `https://homepage.yourdomain.com` - Homepage dashboard with all services
- `https://open-webui.yourdomain.com` - Open WebUI AI interface
- `https://flowise.yourdomain.com` - Flowise AI workflows
- `https://n8n.yourdomain.com` - n8n automation platform
- `https://calibre-web.yourdomain.com` - Calibre Web ebook server
- `https://whisper.yourdomain.com` - Whisper STT (Speech-to-Text) API
- `https://docker-mcp.yourdomain.com` - Docker MCP Gateway (port 3100)

**Local Development Access:**
- Use `kubectl port-forward` for internal service access during development

**Cloudflare Tunnel Benefits:**
- Real SSL certificates from Cloudflare (trusted by all browsers)
- Global CDN access via Cloudflare's network
- Hidden home IP address (enhanced security)
- DDoS protection and enterprise-grade security
- Optional Zero Trust authentication
- Works from any internet connection worldwide

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
4. **Add ingress rule in `modules/cloudflare-tunnel/main.tf`** to tunnel configuration
5. **Add DNS record in `modules/cloudflare-tunnel/main.tf`** to services list
6. **Add Zero Trust app in `modules/cloudflare-tunnel/main.tf`** for authentication (optional)
7. For persistent storage, use the `volume-management` module
8. Run `terraform plan` and `terraform apply`

Note: New services automatically get SSL certificates and DNS records via Cloudflare

### Cloudflare Tunnel Configuration

**IMPORTANT**: The repository uses a **centralized service configuration pattern** via `locals.tf`. All service configurations are defined in one place and automatically propagate to tunnel ingress, DNS records, and Zero Trust policies.

**To add a new service:**

1. **Add service configuration to `locals.tf`**:
```hcl
services = merge(
  # ... existing services ...

  var.enable_my_service ? {
    "my-service" = {
      hostname    = "my-service"
      service_url = "http://my-service.homelab.svc.cluster.local:8080"
      enable_auth = true  # Enable Zero Trust authentication
      type        = "kubernetes"  # or "docker" for Docker containers
    }
  } : {},
)
```

2. **The `cloudflare-tunnel` module automatically creates**:
   - Tunnel ingress rules (from `service_url`)
   - DNS CNAME records (from `hostname`)
   - Zero Trust applications (when `enable_auth = true` and email domains configured)

**Service Configuration Options:**
- `hostname`: Subdomain for the service (e.g., "my-service" → "my-service.yourdomain.com")
- `service_url`: Internal service URL (Kubernetes service or Docker host)
- `enable_auth`: Enable/disable Zero Trust authentication
- `type`: "kubernetes" or "docker" (for documentation)
- `internal`: Set to `true` to skip DNS record creation (for OAuth Worker proxy pattern)

**For Docker containers**, use `host.docker.internal` to route to Docker host:
```hcl
service_url = "http://host.docker.internal:8083"  # For Docker containers
```

**For Kubernetes services**, use the internal DNS format:
```hcl
service_url = "http://service-name.homelab.svc.cluster.local:port"
```

This pattern ensures consistency and eliminates the need to update multiple locations when adding services.

**Cloudflare Tunnel Features:**
- **Automatic SSL**: Real certificates from Cloudflare for all services
- **Zero Trust Ready**: Email authentication for sensitive services  
- **Global CDN**: Fast access via Cloudflare's global network
- **DDoS Protection**: Enterprise-grade security included
- **Hidden Infrastructure**: Home IP never exposed
- **High Availability**: Multiple tunnel connections for redundancy

### Configuration Management
- **Centralized Variables**: Common settings defined in root `variables.tf`
- **Environment Configuration**: Use `terraform.tfvars` for environment-specific values
- **Module Variables**: Each module has standardized variables for consistency
- **Feature Flags**: Enable/disable services using `enable_*` variables
- **Resource Sizing**: Standardized CPU, memory, and storage limits
- **Sensitive Data**: Use Terraform sensitive variables for secrets

## Important Notes

- The repository uses Docker Desktop's local Kubernetes cluster
- All HTTP traffic is automatically redirected to HTTPS via Cloudflare
- Cloudflare Tunnel provides secure external access with real SSL certificates
- Global CDN access enables fast connectivity from anywhere
- Docker socket access is secured through a proxy container
- PostgreSQL service provides shared database functionality
- Docker volumes provide persistent storage with backup/restore capabilities
- All modules follow standardized variable and output patterns
- Feature flags allow selective service deployment

## Zero Trust Authentication (2-Step Deployment)

**Step 1: Basic deployment** (no authentication required)
- Deploy with empty `allowed_email_domains = []` in `terraform.tfvars`
- Services are publicly accessible via HTTPS with real SSL certificates
- Perfect for testing and initial setup

**Step 2: Enable authentication** (optional but recommended)
1. **Enable Cloudflare Access**:
   - Go to https://dash.cloudflare.com/ → Zero Trust → Settings
   - Enable "Access" (requires billing info, but Zero Trust is free for up to 50 users)
2. **Configure authentication** in `terraform.tfvars`:
   ```hcl
   # Option A: Domain-specific (recommended for security)
   allowed_email_domains = ["yourdomain.com"]  # Only allow emails from your domain
   allowed_emails        = []                  # Or specific emails if needed
   
   # Option B: Public email providers (less secure)
   allowed_email_domains = ["gmail.com"]       # Allow any Gmail addresses
   allowed_emails        = ["user@domain.com"] # Specific emails
   ```
3. **Deploy authentication**: `terraform apply`

**Zero Trust Features:**
- **Email Verification**: Users must verify their email before accessing services
- **Session Management**: 24-hour sessions (configurable)
- **CORS Support**: Modern web applications work properly
- **Domain Restrictions**: Limit access by email domain or specific addresses
- **Access Policies**: Granular control per service

## MCP Client Authentication

### For Non-Web MCP Clients (Claude Code, etc.)

**Option 1: Service Tokens (Recommended for Production)**

1. **Create Service Token**:
   ```bash
   # In Cloudflare Zero Trust Dashboard:
   # Access → Service Auth → Service Tokens → Create Service Token
   # Name: "Docker MCP Gateway"
   # Copy the Client ID and Client Secret
   ```

2. **Configure MCP Client**:
   ```json
   {
     "mcpServers": {
       "docker-remote": {
         "type": "sse",
         "url": "https://docker-mcp.yourdomain.com/sse",
         "headers": {
           "CF-Access-Client-Id": "your-service-token-id",
           "CF-Access-Client-Secret": "your-service-token-secret"
         }
       }
     }
   }
   ```

3. **Update Zero Trust Policy** (add to Docker MCP service):
   ```bash
   # In Cloudflare Dashboard:
   # Access → Applications → Docker MCP → Policies
   # Edit policy → Add Include rule → Service Token
   # Select your created service token
   ```

**Option 2: Disable Authentication (Development Only)**
```hcl
# In locals.tf - set enable_auth = false for docker-mcp
"docker-mcp" = {
  hostname     = "docker-mcp"
  service_url  = "http://host.docker.internal:3100"
  enable_auth  = false  # No Zero Trust authentication
  type         = "docker"
}
```

**Option 3: Local Development**
```json
{
  "mcpServers": {
    "docker-local": {
      "type": "sse",
      "url": "http://localhost:3100/sse"  // Bypasses Cloudflare entirely
    }
  }
}
```

**Service Token Benefits:**
- **Programmatic Access**: No browser interaction required
- **Secure**: Scoped to specific applications
- **Rotatable**: Can be regenerated/revoked anytime
- **Auditable**: All access logged in Cloudflare Analytics

## OAuth Worker ↔ Docker MCP Gateway Architecture (Internal)

The OAuth Worker uses **Cloudflare Access Service Tokens** to securely communicate with the Docker MCP Gateway through an internal tunnel route.

### **Architecture Overview**

```
Client (Claude Code)
  ↓ OAuth 2.0 (GitHub authentication)
docker-mcp.rainforest.tools (OAuth Worker - Public)
  ↓ Cloudflare Tunnel + Service Token Headers
docker-mcp-internal.rainforest.tools (Protected - DNS exists but auth required)
  ↓ Tunnel routing
host.docker.internal:3100 (Docker MCP Gateway)
```

### **Security Layers**

1. **Public Endpoint** (`docker-mcp.rainforest.tools`):
   - GitHub OAuth authentication for end users
   - OAuth Worker validates user identity
   - Managed by Cloudflare Worker

2. **Internal Endpoint** (`docker-mcp-internal.rainforest.tools`):
   - DNS record exists (required for Worker-to-Worker communication)
   - Protected by Zero Trust service token authentication
   - Only accessible with valid service token headers
   - Blocks all public internet access
   - Optional: Also accessible via your email domain (for debugging)

3. **Network Isolation**:
   - Docker MCP Gateway only reachable via Cloudflare Tunnel
   - No direct internet exposure

### **Setup (Hybrid Manual + Automated)**

**Step 1: Create Service Token (One-Time Manual Setup)**

```bash
# 1. Navigate to Cloudflare Dashboard:
#    https://dash.cloudflare.com/ → Zero Trust → Access → Service Auth → Service Tokens

# 2. Click "Create Service Token"
#    Name: "OAuth Worker - Docker MCP Internal"
#    Duration: Leave empty (token never expires)

# 3. Copy BOTH values immediately (you can't view Client Secret later!):
#    - Client ID (e.g., "a1b2c3d4e5f6...")
#    - Client Secret (e.g., "x1y2z3...")
```

**Step 2: Configure Terraform (One-Time)**

Add to `terraform.tfvars`:

```hcl
# Add service token ID to the list (for Zero Trust policy)
service_token_ids = ["a1b2c3d4e5f6..."]  # Your Client ID from Step 1

# Add OAuth Worker credentials (for Worker secrets automation)
oauth_worker_service_token_client_id     = "a1b2c3d4e5f6..."  # Client ID
oauth_worker_service_token_client_secret = "x1y2z3..."        # Client Secret
```

**Step 3: Deploy Infrastructure**

```bash
terraform plan   # Review DNS and Worker secrets changes
terraform apply  # Terraform automatically:
                 # - Creates DNS record for docker-mcp-internal
                 # - Creates Zero Trust Access Application
                 # - Configures OAuth Worker secrets (SERVICE_TOKEN_ID, SERVICE_TOKEN_SECRET)
```

**Step 4: Create Access Policy Manually** (Required)

Cloudflare API limitations require manual policy creation in the Dashboard:

```bash
# 1. Navigate to: Zero Trust → Access → Applications
# 2. Find "Docker-Mcp-Internal - homelab" → Click "Edit"
# 3. Go to "Policies" tab → Click "Add a policy"
# 4. Configure:
#    - Name: "OAuth Worker Service Token"
#    - Action: "Service Auth" (NOT "Allow")
#    - Configure rules → Add include → Service Token → Select your token
# 5. Save policy → Save application
```

**What Terraform Automates:**
- ✅ DNS record for `docker-mcp-internal.rainforest.tools`
- ✅ Zero Trust Access Application creation
- ✅ Worker secrets configured automatically
- ✅ Tunnel routing to Docker MCP Gateway

**What You Do Once:**
- ✅ Create service token in Dashboard (more secure - not in Terraform state)
- ✅ Add credentials to `terraform.tfvars` (gitignored)
- ✅ Create Access Policy manually (Cloudflare API limitation)

**Verify Setup:**

```bash
# 1. Check Terraform outputs for policy validation
terraform output cloudflare_policy_check
# Should show: has_service_token_policy = true, total_policies = "2"

# 2. Check for manual setup warnings
terraform output manual_setup_warning
# Should return: null (if policy exists) or show warning instructions

# 3. DNS record exists
dig docker-mcp-internal.rainforest.tools
# Should return: CNAME to *.cfargotunnel.com

# 4. Zero Trust authentication active
curl -I https://docker-mcp-internal.rainforest.tools/sse
# Should return: HTTP/2 302 (redirect to login)

# 5. Worker secrets configured
# Cloudflare Dashboard → Workers & Pages → homelab-oauth-gateway → Settings → Variables
# Should see: SERVICE_TOKEN_ID, SERVICE_TOKEN_SECRET
```

**Automated Policy Detection:**

Terraform now automatically detects if the service token policy is missing:
- ✅ **Automatic Validation**: Checks Cloudflare API for service token policy after every apply
- ✅ **Clear Warnings**: Shows detailed setup instructions if policy is missing
- ✅ **Status Output**: `terraform output cloudflare_policy_check` shows policy status
- ✅ **No More Silent Failures**: 502 errors are prevented by detecting missing policies

### **OAuth Worker Code Implementation**

The OAuth Worker includes service token headers when proxying to `docker-mcp-internal`:

```typescript
// After OAuth authentication succeeds
const upstreamRequest = new Request(
  `https://docker-mcp-internal.${env.DOMAIN_SUFFIX}${new URL(request.url).pathname}`,
  {
    method: request.method,
    headers: {
      ...Object.fromEntries(request.headers),
      // Add service token headers for Zero Trust authentication
      'CF-Access-Client-Id': env.SERVICE_TOKEN_ID,
      'CF-Access-Client-Secret': env.SERVICE_TOKEN_SECRET,
    },
    body: request.body,
  }
);

return fetch(upstreamRequest);
```

### **Testing & Verification**

**Test 1: Direct access should be blocked**
```bash
curl https://docker-mcp-internal.rainforest.tools/sse
# Expected: 403 Forbidden or Zero Trust login page
```

**Test 2: Access with service token (simulate OAuth Worker)**
```bash
curl https://docker-mcp-internal.rainforest.tools/sse \
  -H "CF-Access-Client-Id: <your-client-id>" \
  -H "CF-Access-Client-Secret: <your-client-secret>"
# Expected: 200 OK or appropriate response from MCP Gateway
```

**Test 3: End-to-end OAuth flow**
```bash
# Use MCP client with OAuth configuration
# Should successfully authenticate and connect through OAuth Worker
```

**Monitor Access Logs:**
```bash
# Cloudflare Dashboard → Zero Trust → Logs → Access
# Filter by application: "Docker MCP Internal"
# Should see OAuth Worker requests with service token authentication
```

### **Service Token Management**

**Token Properties:**
- ✅ **Never Expires** (when created without duration)
- ✅ **Stored Securely** (Cloudflare Worker secrets are encrypted)
- ✅ **Never Leaves Cloudflare Network** (Worker-to-Tunnel communication stays internal)
- ✅ **Auditable** (All requests logged in Access Logs)

**Rotation (if needed):**
```bash
# Terraform manages token lifecycle - just taint and reapply
terraform taint module.cloudflare_tunnel.cloudflare_zero_trust_access_service_token.oauth_worker
terraform apply

# Terraform will:
# 1. Create new service token
# 2. Update Worker secrets automatically
# 3. Update Zero Trust policy
# 4. Delete old token
# Zero downtime - Workers update automatically
```

**Security Best Practices:**
- ✅ Service token credentials managed entirely by Terraform
- ✅ Credentials stored securely in Terraform state (encrypted at rest)
- ✅ Worker secrets updated automatically
- ✅ No manual credential handling required
- ✅ Regularly review Access Logs for unusual activity
- ✅ Token rotation via `terraform taint` if compromised

### **Troubleshooting**

**530 Error (Tunnel cannot reach upstream):**
```bash
# Verify Docker MCP Gateway is running
docker ps --filter "name=homelab-docker-mcp-gateway"

# Check tunnel can reach host.docker.internal
kubectl run test-host --rm -it --restart=Never --image=curlimages/curl -- \
  curl -I http://host.docker.internal:3100
```

**403 Forbidden:**
```bash
# Check service token exists in Cloudflare
# Dashboard → Zero Trust → Access → Service Auth → Service Tokens
# Should see: "homelab-oauth-worker-service-token"

# Verify Worker secrets were created
# Dashboard → Workers & Pages → homelab-oauth-gateway → Settings → Variables
# Should show: SERVICE_TOKEN_ID, SERVICE_TOKEN_SECRET

# Force recreation if needed
terraform taint module.oauth_worker[0].cloudflare_workers_secret.service_token_id
terraform taint module.oauth_worker[0].cloudflare_workers_secret.service_token_secret
terraform apply
```

**DNS Resolution Failure:**
```bash
# Verify DNS record was created
dig docker-mcp-internal.rainforest.tools
# Should return CNAME pointing to tunnel

# Check Cloudflare Dashboard → DNS → Records
# Should see: docker-mcp-internal CNAME <tunnel-id>.cfargotunnel.com
```

## Persistent OAuth Setup (Recommended)

The OAuth Worker now provides **persistent client registration** managed by Terraform. This ensures OAuth credentials survive deployments and infrastructure changes.

### **Automatic Client Registration**

Terraform automatically registers an OAuth client when deploying the infrastructure:

```bash
terraform apply
```

The client registration happens via:
1. **OAuth Worker Deployment**: Professional TypeScript OAuth Worker with GitHub authentication
2. **Client Registration**: Terraform runs `scripts/register-oauth-client.sh` automatically
3. **Credential Storage**: Client ID and secret stored in local files for persistence
4. **Output Generation**: Terraform outputs provide ready-to-use MCP configuration

### **Using Persistent Credentials**

After `terraform apply`, get your persistent OAuth credentials:

```bash
# Get client ID
terraform output claude_oauth_client_id

# Get client secret
terraform output claude_oauth_client_secret
```

### **MCP Client Configuration**

Use the Terraform-generated credentials for permanent OAuth setup:

```json
{
  "mcpServers": {
    "docker-remote": {
      "type": "sse",
      "url": "https://docker-mcp.rainforest.tools/sse",
      "oauth": {
        "client_id": "3E4n4MoSYkyIXXBo",
        "client_secret": "jkpYLZKtgGJfi0gT6wKgIqEm8KGBimGt"
      }
    }
  }
}
```

### **Benefits of Persistent OAuth**

- ✅ **Infrastructure as Code**: OAuth client managed by Terraform
- ✅ **Deployment Resilience**: Credentials persist across Worker redeployments  
- ✅ **Automatic Registration**: No manual client setup required
- ✅ **Team Sharing**: Consistent credentials across team members
- ✅ **Backup & Restore**: Credentials stored in Terraform state
- ✅ **Professional OAuth 2.0**: Full GitHub authentication flow with approval dialog

### **Manual Client Registration** (Alternative)

If needed, you can manually register additional clients:

```bash
# Run the registration script
./scripts/register-oauth-client.sh

# Or use curl directly
curl -X POST "https://docker-mcp.rainforest.tools/register" \
  -H "Content-Type: application/json" \
  -d '{"client_name": "My Client", "redirect_uris": ["https://example.com/callback"]}'
```

## Whisper Speech-to-Text Service

The homelab includes a self-hosted **Whisper STT API** for speech-to-text transcription using OpenAI's Whisper model.

### **Architecture**
- **Deployment**: Docker container (simple, like Calibre Web)
- **Engine**: faster-whisper (4-5x faster than vanilla Whisper)
- **API**: OpenAI-compatible endpoint (`/v1/audio/transcriptions`)
- **Model Cache**: Persistent Docker volume (~1-2GB)
- **Access**: HTTPS via Cloudflare Tunnel with optional Zero Trust auth

### **Features**
- ✅ **OpenAI API Compatible** - Works with n8n, Flowise, Open WebUI
- ✅ **Fast CPU Performance** - Optimized for Docker Desktop (no GPU required)
- ✅ **GPU Ready** - Set `enable_gpu = true` if GPU available later
- ✅ **Automatic Language Detection** - Supports 99+ languages
- ✅ **Voice Activity Detection** - Filters silence for better accuracy
- ✅ **Built with UV** - Fast Python package management

### **Enabling Whisper**

**1. Enable in `terraform.tfvars`:**
```hcl
enable_whisper = true
```

**2. Deploy:**
```bash
terraform apply
```

**3. First run downloads model (~150MB for 'base'):**
```bash
# Check logs to see model download progress
docker logs -f homelab-whisper
```

### **Model Selection**

**Default Configuration** (optimized for Mac CPU):
```hcl
module "whisper" {
  model_size = "base"  # Fast, low-memory, good quality
  enable_gpu = false   # Set true for PC with GPU
}
```

**Model Performance Comparison** (Tested on Mac CPU):
| Model | Size | Speed (39min audio) | CPU | Memory | Quality | Use Case |
|-------|------|---------------------|-----|--------|---------|----------|
| tiny | 39MB | 61s (38x) | 606% | 500MB | 96% conf | Ultra-fast drafts |
| **base** | **74MB** | **65s (36x)** | **606%** | **750MB** | **97% conf** | **✓ Recommended for Mac** |
| small | 244MB | 312s (7.5x) | 476% | 1.5GB | 99% conf | Important meetings |
| medium | 769MB | ~600s (4x) | 500% | 2GB | 99% conf | Production quality |
| large-v3 | 1.5GB | ~900s (2.5x) | 500% | 3GB | 99% conf | Maximum accuracy |

**Recommendations:**
- **Mac (Dev)**: Use `base` - Fast processing, low resource usage, good for iteration
- **PC with RTX 5070**: Use `medium` or `large-v3` with GPU - 10-20x faster than CPU

### **Dynamic Model Selection** (New Feature)

Override default model per request:
```bash
curl -X POST "https://whisper.yourdomain.com/v1/audio/transcriptions" \
  -F "file=@audio.mp3" \
  -F "whisper_model=small"  # Use specific model for this request
```

Available models: `tiny`, `base`, `small`, `medium`, `large-v2`, `large-v3`

### **API Usage**

**Direct API call:**
```bash
curl -X POST "https://whisper.yourdomain.com/v1/audio/transcriptions" \
  -F "file=@audio.mp3" \
  -F "model=whisper-1"
```

**Response:**
```json
{
  "text": "This is the transcribed text from your audio file.",
  "language": "en",
  "duration": 12.5,
  "language_probability": 0.98
}
```

### **Service Integration**

**Open WebUI** (Automatic):
- Whisper STT automatically configured when `enable_whisper = true`
- Click microphone icon in chat to use voice input
- Transcription happens via `https://whisper.yourdomain.com`

**n8n** (Manual configuration):
1. Add OpenAI node to workflow
2. Set custom base URL: `https://whisper.yourdomain.com/v1`
3. Use "Create Transcription" operation
4. Upload audio file via workflow

**Flowise** (Manual configuration):
1. Add "OpenAI Whisper" node to flow
2. Configure custom endpoint: `https://whisper.yourdomain.com/v1`
3. Connect to your workflow

### **Local Development**

**Test without Cloudflare Tunnel:**
```bash
# Internal URL (no auth required)
curl -X POST "http://localhost:9000/v1/audio/transcriptions" \
  -F "file=@test.mp3"
```

**Health check:**
```bash
curl http://localhost:9000/health
# {"status": "healthy", "model": "base", "device": "cpu"}
```

### **Performance Optimization**

**CPU (Current Setup):**
- Model: `base` (~5x realtime speed)
- Memory: ~1GB during transcription
- Typical: 30-second audio transcribed in ~6 seconds

**GPU (Future):**
```hcl
module "whisper" {
  enable_gpu = true  # Requires NVIDIA GPU + drivers
  model_size = "large-v3"  # Can use larger models
}
```

### **Troubleshooting**

**View logs:**
```bash
docker logs -f homelab-whisper
```

**Rebuild after code changes:**
```bash
terraform taint module.whisper[0].docker_image.whisper
terraform apply
```

**Clear model cache:**
```bash
docker volume rm homelab-whisper-models-data
terraform apply  # Will re-download models
```

**Check container status:**
```bash
docker ps --filter "name=homelab-whisper"
```

## Monitoring Integration with Raspberry Pi

The homelab services integrate with the Raspberry Pi 5 monitoring stack (rainforest-iot) for centralized observability.

### **Architecture**

**Mac Mini (homelab)** → **Raspberry Pi (monitoring)**
- Mac Mini: Runs workload services (Open WebUI, Flowise, n8n, PostgreSQL, MinIO, etc.)
- Raspberry Pi: Runs monitoring stack (Prometheus, Grafana, Loki, AlertManager)
- Connection: Direct LAN connectivity (Mac: 192.168.0.30, Pi: 192.168.0.134)

### **Enabled Metrics**

**PostgreSQL** ([main.tf:48](/Users/rainforest/Repositories/rainforest-homelab/main.tf#L48)):
- Metrics endpoint: `http://192.168.0.30:30432/metrics`
- Exporter: postgres_exporter (Bitnami chart built-in)
- Scrape interval: 30s
- Metrics: connections, transactions, queries, locks, database sizes

**MinIO** ([modules/minio/main.tf:99](/Users/rainforest/Repositories/rainforest-homelab/modules/minio/main.tf#L99)):
- Metrics endpoint: `http://192.168.0.30:30900/minio/v2/metrics/cluster`
- Auth: Public (MINIO_PROMETHEUS_AUTH_TYPE = "public")
- Scrape interval: 30s
- Metrics: storage usage, API requests, network I/O, bucket statistics

**HTTP Health Checks** (Blackbox Exporter on Pi):
- Monitors all Cloudflare Tunnel endpoints
- Services: Open WebUI, Flowise, n8n, Calibre Web, Whisper, MinIO, pgAdmin, S3
- Check interval: 30s
- Metrics: HTTP response time, SSL certificate validity, service availability

**Log Aggregation** ([main.tf:333](/Users/rainforest/Repositories/rainforest-homelab/main.tf#L333)):
- Promtail DaemonSet: Ships all K8s logs to Pi Loki
- Loki endpoint: `http://192.168.0.134:30100/loki/api/v1/push`
- Logs: All pods in `homelab` namespace
- Retention: 7 days (configured on Pi Loki)

### **Deployment Steps**

**1. Deploy monitoring changes to homelab (Mac Mini)**:
```bash
cd /Users/rainforest/Repositories/rainforest-homelab
terraform plan  # Review PostgreSQL metrics enable + NodePort services
terraform apply # Deploy changes
```

**2. Deploy scrape configs to IoT monitoring (Raspberry Pi)**:
```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform plan  # Review new Mac Mini scrape targets
terraform apply # Update Prometheus configuration
```

**3. Verify metrics collection**:
```bash
# Check metrics endpoints are accessible from Pi
curl http://192.168.0.30:30432/metrics  # PostgreSQL
curl http://192.168.0.30:30900/minio/v2/metrics/cluster  # MinIO

# Access Grafana (from browser)
open http://raspberrypi-5.local:30080  # Login: admin/admin123

# Check Prometheus targets
open http://raspberrypi-5.local:30090/targets
```

### **Grafana Dashboards**

**Available dashboards**:
- **Homelab Overview**: Unified view of Mac Mini + Pi services
- **Kubernetes Cluster**: K3s cluster metrics (Pi) + Docker Desktop metrics (Mac)
- **PostgreSQL**: Database performance, connections, query statistics
- **MinIO**: Storage capacity, API requests, bucket usage

**Import additional dashboards**:
1. Navigate to Grafana → Dashboards → Import
2. Use dashboard IDs:
   - PostgreSQL: `9628` (official PostgreSQL dashboard)
   - MinIO: `13502` (MinIO metrics dashboard)
   - Docker: `1229` (Docker container metrics)

### **Troubleshooting**

**Metrics not showing in Prometheus**:
```bash
# Verify NodePort services are running
kubectl get svc -n homelab | grep metrics

# Check if ports are exposed
kubectl get svc homelab-postgresql-metrics -n homelab
kubectl get svc homelab-minio-metrics -n homelab

# Test from Mac Mini
curl localhost:30432/metrics  # PostgreSQL
curl localhost:30900/minio/v2/metrics/cluster  # MinIO
```

**Prometheus scrape errors**:
```bash
# SSH to Raspberry Pi and test connectivity
ssh rainforest@raspberrypi-5.local
curl http://192.168.0.30:30432/metrics  # Should return metrics

# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus-server --tail=100
```

**Network connectivity issues**:
```bash
# Verify LAN connectivity
ping 192.168.0.30  # Mac Mini
ping 192.168.0.134  # Raspberry Pi

# Check firewall (macOS)
sudo pfctl -s rules  # Verify no blocking rules
```

## Security Considerations

- **Cloudflare API Credentials**: The `cloudflare_api_token` and `cloudflare_account_id` variables are marked as sensitive in Terraform
- **Tunnel Security**: Runs with minimal privileges, non-root user, and read-only filesystem
- **Network Isolation**: Home IP address is completely hidden from the internet
- **HTTPS Everywhere**: All traffic encrypted end-to-end through Cloudflare tunnels with automatic SSL termination
- **Zero Trust Ready**: Optional email authentication for additional security layers
- **DDoS Protection**: Enterprise-grade protection via Cloudflare's global network
- **Whisper API Access**: Protected by Cloudflare Zero Trust authentication (recommended for production)
- **Metrics Security**: NodePort services only accessible on local LAN (not exposed via Cloudflare Tunnel)