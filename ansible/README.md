# Ansible MCP Gateway Deployment

This directory contains an Ansible playbook alternative for deploying Docker MCP Gateway to the homelab Kubernetes cluster.

## Prerequisites

1. **Ansible Installation**:
   ```bash
   pip install ansible
   ```

2. **Kubernetes Collection**:
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

3. **Kubernetes Access**:
   - Ensure `kubectl` is configured with OrbStack context
   - Test access: `kubectl get nodes`

## Usage

### Basic Deployment

```bash
cd ansible/
ansible-playbook mcp-gateway-playbook.yml
```

### Custom Configuration

Create a vars file `custom-vars.yml`:

```yaml
---
namespace: homelab
gateway_port: 8080
transport_mode: sse

# Custom MCP servers
mcp_servers:
  docker:
    image: "mcp/docker"
    description: "Docker MCP server"
    environment:
      DOCKER_HOST: "tcp://dockerproxy:2375"
  
  custom-server:
    image: "myorg/custom-mcp-server:latest"
    description: "Custom MCP server"
    environment:
      API_KEY: "secret-key"

# Security settings
security_block_network: true
cors_origins:
  - "https://trusted-domain.com"

# Resource allocation
resource_limits:
  cpu: "2000m"
  memory: "4Gi"
```

Deploy with custom configuration:

```bash
ansible-playbook mcp-gateway-playbook.yml -e @custom-vars.yml
```

### Environment-Specific Deployments

For different environments, create inventory files:

**inventory/development.yml**:
```yaml
all:
  vars:
    namespace: homelab-dev
    gateway_port: 8080
    cors_origins: ["*"]
    security_block_network: false
```

**inventory/production.yml**:
```yaml
all:
  vars:
    namespace: homelab-prod
    gateway_port: 8080
    cors_origins: ["https://production-domain.com"]
    security_block_network: true
```

Deploy to specific environment:
```bash
ansible-playbook -i inventory/development.yml mcp-gateway-playbook.yml
```

## Verification

After deployment, verify the installation:

```bash
# Check deployment status
kubectl get deployment mcp-gateway -n homelab

# Check pod status
kubectl get pods -n homelab -l app=mcp-gateway

# Check service
kubectl get svc mcp-gateway -n homelab

# Check ingress route
kubectl get ingressroute mcp-gateway -n homelab

# View logs
kubectl logs -n homelab deployment/mcp-gateway
```

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   ```bash
   # Ensure proper kubeconfig
   kubectl config current-context
   kubectl auth can-i create deployments --namespace=homelab
   ```

2. **Collection Not Found**:
   ```bash
   ansible-galaxy collection install kubernetes.core
   ```

3. **Deployment Stuck**:
   ```bash
   # Check pod events
   kubectl describe pod -n homelab -l app=mcp-gateway
   
   # Check resource constraints
   kubectl top nodes
   kubectl top pods -n homelab
   ```

### Playbook Options

The playbook supports various customization options:

```bash
# Dry run (check mode)
ansible-playbook mcp-gateway-playbook.yml --check

# Verbose output
ansible-playbook mcp-gateway-playbook.yml -vvv

# Skip certain tasks
ansible-playbook mcp-gateway-playbook.yml --skip-tags verification

# Run only specific tasks
ansible-playbook mcp-gateway-playbook.yml --tags deploy
```

## Comparison with Terraform

### Ansible Advantages
- **Procedural**: Step-by-step execution
- **Flexibility**: Rich templating with Jinja2
- **Agentless**: No state files to manage
- **Integration**: Easy integration with existing automation

### Terraform Advantages (Recommended)
- **Declarative**: Infrastructure as code
- **State Management**: Tracks resource lifecycle
- **Dependency Resolution**: Automatic ordering
- **Provider Ecosystem**: Rich Kubernetes support

## Integration with CI/CD

Example GitLab CI pipeline:

```yaml
stages:
  - deploy

deploy_mcp_gateway:
  stage: deploy
  image: quay.io/ansible/ansible-runner:latest
  before_script:
    - ansible-galaxy collection install -r ansible/requirements.yml
  script:
    - ansible-playbook ansible/mcp-gateway-playbook.yml
  only:
    - main
```

## Security Considerations

1. **Secrets Management**:
   - Use Ansible Vault for sensitive data
   - Environment variables for CI/CD

2. **RBAC**:
   - Ensure service account has proper permissions
   - Limit namespace access

3. **Network Policies**:
   - Consider implementing network policies
   - Restrict ingress traffic

## Maintenance

### Updates

Update MCP Gateway image:
```bash
ansible-playbook mcp-gateway-playbook.yml -e image_tag=v2.0.0
```

### Scaling

Scale deployment:
```bash
kubectl scale deployment mcp-gateway -n homelab --replicas=3
```

### Backup Configuration

```bash
# Backup ConfigMap
kubectl get configmap mcp-gateway-config -n homelab -o yaml > backup/mcp-config.yaml

# Backup Secret
kubectl get secret mcp-gateway-secret -n homelab -o yaml > backup/mcp-secret.yaml
```