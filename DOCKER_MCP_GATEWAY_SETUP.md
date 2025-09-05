# Docker MCP Gateway Remote Setup Guide

This guide provides step-by-step instructions for deploying and configuring Docker MCP Gateway for remote access from Mac or any other client.

## Overview

The Docker MCP Gateway solution provides:

- **Remote Docker Control**: Access Docker operations from anywhere via MCP protocol
- **Secure External Access**: Cloudflare Tunnel with Zero Trust authentication
- **Kubernetes-Based**: Scalable, reliable container deployment
- **Multi-Client Support**: Works with any MCP-compatible client

## Architecture

```
Client (Mac) → Cloudflare Edge → Tunnel → Kubernetes → Docker MCP Gateway → Docker Socket
```

## Prerequisites

### Required
- Docker Desktop with Kubernetes enabled
- Cloudflare account with a registered domain
- Terraform >= 1.0 or Ansible >= 2.9
- kubectl configured for Docker Desktop

### Optional
- Cloudflare Zero Trust for authentication
- Prometheus for monitoring

## Setup Methods

### Method 1: Terraform (Recommended)

#### 1. Enable Docker MCP Gateway

Edit your `terraform.tfvars`:

```hcl
# Feature Flags
enable_docker_mcp_gateway = true
enable_cloudflare_tunnel = true

# Domain Configuration
domain_suffix = "yourdomain.com"
cloudflare_account_id = "your-account-id"
cloudflare_api_token = "your-api-token"

# Zero Trust Authentication (recommended)
allowed_email_domains = ["yourdomain.com"]
# OR specific emails
# allowed_emails = ["admin@yourdomain.com"]
```

#### 2. Deploy Infrastructure

```bash
# Initialize Terraform (if first time)
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

#### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n homelab -l app=docker-mcp-gateway

# View logs
kubectl logs -n homelab -l app=docker-mcp-gateway -f

# Test internal connectivity
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 8080:8080
curl http://localhost:8080/health
```

#### 4. Configure External Access

The Cloudflare Tunnel is automatically configured with the following:

- **Hostname**: `docker-mcp.yourdomain.com`
- **Internal Service**: `homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080`
- **SSL**: Automatic via Cloudflare

### Method 2: Ansible Alternative

#### 1. Configure Variables

Edit `automation/group_vars/all.yml`:

```yaml
# Docker MCP Gateway configuration
docker_mcp_gateway:
  enabled: true
  replicas: 1
  port: 8080
  tunnel_hostname: docker-mcp
  domain_suffix: "yourdomain.com"
  enable_docker_socket: true
  log_level: info
```

#### 2. Deploy with Ansible

```bash
cd automation

# Install required collections
ansible-galaxy collection install kubernetes.core

# Deploy Docker MCP Gateway
ansible-playbook -i inventory.yml docker-mcp-gateway.yml
```

#### 3. Manual Cloudflare Tunnel Configuration

Add to your Cloudflare Tunnel configuration:

```yaml
# In cloudflared config
ingress:
  - hostname: docker-mcp.yourdomain.com
    service: http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080
```

## Client Configuration

### Mac Setup

#### 1. Install MCP Client

```bash
# Using npm
npm install -g @modelcontextprotocol/client

# Or using pip
pip install mcp-client
```

#### 2. Configure MCP Client

Create `~/.mcp/config.json`:

```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "mcp-client",
      "args": [
        "--server", "https://docker-mcp.yourdomain.com",
        "--auth-type", "bearer"
      ],
      "type": "http",
      "env": {
        "MCP_SERVER_URL": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

#### 3. Test Connection

```bash
# Test health endpoint
curl https://docker-mcp.yourdomain.com/health

# Test MCP functionality (example)
mcp-client call --server https://docker-mcp.yourdomain.com \
  --method docker.container.list \
  --params '{}'
```

### Integration with Open WebUI

If using Open WebUI, configure MCP server:

```json
{
  "mcpServers": {
    "docker-remote": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"],
      "type": "stdio",
      "env": {
        "DOCKER_HOST": "https://docker-mcp.yourdomain.com"
      }
    }
  }
}
```

## Security Configuration

### Zero Trust Authentication

#### 1. Enable in Cloudflare Dashboard

1. Go to **Zero Trust** → **Access** → **Applications**
2. Create new application for `docker-mcp.yourdomain.com`
3. Set authentication policy:

```
Policy Name: Docker MCP Access
Assign to: docker-mcp.yourdomain.com
Include: Email domain is yourdomain.com
```

#### 2. Test Authentication

Visit `https://docker-mcp.yourdomain.com` in browser:
- Should redirect to authentication
- Enter email matching allowed domain
- Should redirect back to service

### Network Security

#### Enable Network Policies (Optional)

```hcl
# In terraform.tfvars
enable_docker_mcp_gateway = true

# In module configuration
module "docker_mcp_gateway" {
  # ... other config
  enable_network_policy = true
}
```

#### Docker Socket Security

⚠️ **Warning**: Docker socket access provides significant privileges. Consider:

- Deploying only in trusted environments
- Using read-only operations where possible
- Monitoring container activities
- Implementing audit logging

## Monitoring and Troubleshooting

### Health Checks

```bash
# Internal health check
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- \
  wget -qO- http://localhost:8080/health

# External health check
curl https://docker-mcp.yourdomain.com/health
```

### Log Analysis

```bash
# View application logs
kubectl logs -n homelab -l app=docker-mcp-gateway -f

# View Cloudflare Tunnel logs
kubectl logs -n homelab -l app=cloudflared -f

# Check events
kubectl get events -n homelab --sort-by='.lastTimestamp' | grep docker-mcp
```

### Common Issues

#### 1. Pod Won't Start

**Symptoms**: Pod in `CrashLoopBackOff` or `ImagePullBackOff`

**Solutions**:
```bash
# Check pod describe
kubectl describe pod -n homelab -l app=docker-mcp-gateway

# Check image availability
docker pull alpine:3.19

# Verify Docker socket
ls -la /var/run/docker.sock
```

#### 2. Docker Socket Permission Denied

**Symptoms**: "permission denied" in logs

**Solutions**:
```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# Verify security context
kubectl get pod -n homelab -l app=docker-mcp-gateway -o yaml | grep -A 10 securityContext

# Test socket access
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- \
  ls -la /var/run/docker.sock
```

#### 3. External Access Not Working

**Symptoms**: Can't reach `https://docker-mcp.yourdomain.com`

**Solutions**:
```bash
# Check Cloudflare Tunnel status
kubectl logs -n homelab -l app=cloudflared --tail=50

# Verify DNS records
dig docker-mcp.yourdomain.com

# Test internal connectivity
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 8080:8080
curl http://localhost:8080/health
```

#### 4. Authentication Issues

**Symptoms**: Redirected to authentication but can't access

**Solutions**:
1. Verify email domain in Cloudflare Zero Trust
2. Check Access application configuration
3. Try incognito/private browsing mode
4. Clear Cloudflare cookies

### Performance Tuning

#### Resource Optimization

```hcl
# For high-traffic environments
module "docker_mcp_gateway" {
  # ... other config
  replicas     = 3
  cpu_limit    = "1000m"
  memory_limit = "2Gi"
}
```

#### Scaling Considerations

- **Horizontal**: Increase replicas for load distribution
- **Vertical**: Increase CPU/memory for complex operations
- **Monitoring**: Enable metrics for performance insights

## Advanced Configuration

### Custom Docker Image

Create custom image with additional tools:

```dockerfile
FROM alpine:3.19

RUN apk add --no-cache \
    docker-cli \
    curl \
    jq \
    bash

# Install MCP tools
RUN curl -L https://github.com/docker/mcp-gateway/releases/latest/download/mcp-gateway-linux -o /usr/local/bin/mcp-gateway
RUN chmod +x /usr/local/bin/mcp-gateway

EXPOSE 8080
CMD ["mcp-gateway", "run", "--config", "/config/config.json"]
```

Update module:

```hcl
module "docker_mcp_gateway" {
  # ... other config
  docker_image = "your-registry/custom-mcp-gateway:latest"
}
```

### Metrics and Monitoring

Enable Prometheus metrics:

```hcl
module "docker_mcp_gateway" {
  # ... other config
  enable_metrics = true
  metrics_port   = 9090
}
```

Access metrics:
```bash
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 9090:9090
curl http://localhost:9090/metrics
```

## Next Steps

1. **Test Docker Operations**: Verify container management works
2. **Set Up Monitoring**: Configure alerts for service health
3. **Document Workflows**: Create team documentation for usage
4. **Security Review**: Audit Docker socket access and permissions
5. **Backup Strategy**: Plan for configuration and data backup

## Support

For additional help:

- **Terraform Issues**: Check module README and variables
- **Ansible Issues**: Review playbook logs and Kubernetes events  
- **Cloudflare Issues**: Check tunnel status and DNS configuration
- **Docker Issues**: Verify socket access and container permissions

## References

- [Docker MCP Gateway Documentation](https://docs.docker.com/ai/mcp-gateway/)
- [Cloudflare Tunnel Setup](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Model Context Protocol](https://modelcontextprotocol.io/)