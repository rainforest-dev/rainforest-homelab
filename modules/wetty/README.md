# Wetty Module

This module deploys [Wetty](https://github.com/butlerx/wetty) as a web terminal service to your Kubernetes cluster using kubectl manifests.

## Features

- Wetty deployment with security contexts and resource limits
- Internal-only access (no external exposure via Cloudflare Tunnel)
- Configurable resource limits and user settings
- ClusterIP service for internal cluster access
- Optional persistent storage support

## Security

**Important**: This module deploys Wetty as an internal-only service with no external exposure. It is designed for private network access only, consistent with security best practices.

- No ingress or external load balancer exposure
- ClusterIP service type only
- Non-root container execution
- Read-only root filesystem where possible
- Resource limits enforced

## Usage

### Basic Deployment

```hcl
module "wetty" {
  source = "./modules/wetty"

  project_name    = "homelab"
  environment     = "production"
  cpu_limit       = "200m"
  memory_limit    = "256Mi"
  wetty_user      = "terminal"
}
```

### Accessing Wetty

Since Wetty is deployed as an internal-only service, access it using kubectl port-forwarding:

```bash
# Enable Wetty in terraform.tfvars
enable_wetty = true

# Deploy Wetty
terraform apply

# Port-forward to access Wetty
kubectl port-forward -n homelab service/homelab-wetty 3000:3000

# Then open your browser to:
# http://localhost:3000
```

### Mobile and Remote Access via Tailscale

If you have Tailscale configured on your Kubernetes cluster host:

1. **Set up port-forward on your cluster host:**
   ```bash
   kubectl port-forward -n homelab service/homelab-wetty 3000:3000
   ```

2. **Access via Tailscale IP:**
   - Find your machine's Tailscale IP: `tailscale ip`
   - Access from any Tailscale device: `http://your-tailscale-ip:3000`

3. **Using Tailscale Magic DNS (recommended):**
   - Access via machine name: `http://your-machine-name:3000`
   - More user-friendly than IP addresses

### Security and Authentication

The default setup creates a user account within the container:
- Username: `terminal` (or custom via `wetty_user` variable)
- Password: `wetty123` 

**Important Security Notes:**
- Change the default password in production
- This setup is intended for private homelab use only
- No external network exposure (consistent with security requirements)
- Consider implementing SSH key authentication for enhanced security

### Production Security Recommendations

For production environments, consider these enhancements:

1. **SSH Key Authentication:**
   ```bash
   # Generate SSH keys for wetty user
   ssh-keygen -t ed25519 -f ~/.ssh/wetty_key
   
   # Mount keys as Kubernetes secrets
   kubectl create secret generic wetty-ssh-keys \
     --from-file=authorized_keys=~/.ssh/wetty_key.pub \
     -n homelab
   ```

2. **Custom User Management:**
   - Integrate with existing user directory (LDAP/AD)
   - Use SSH keys instead of passwords
   - Implement session timeouts

3. **Network Policies:**
   - Restrict pod-to-pod communication
   - Limit egress traffic as needed

## Variables

| Name                | Description                     | Type     | Default                            | Required |
| ------------------- | ------------------------------- | -------- | ---------------------------------- | :------: |
| `project_name`      | Project name for resource naming | `string` | `"homelab"`                       |    no    |
| `environment`       | Environment name                | `string` | `"dev"`                           |    no    |
| `namespace`         | Kubernetes namespace            | `string` | `"homelab"`                       |    no    |
| `cpu_limit`         | CPU limit for Wetty            | `string` | `"200m"`                          |    no    |
| `memory_limit`      | Memory limit for Wetty         | `string` | `"256Mi"`                         |    no    |
| `enable_persistence`| Enable persistent storage       | `bool`   | `false`                           |    no    |
| `storage_size`      | Storage size for Wetty         | `string` | `"1Gi"`                           |    no    |
| `wetty_user`        | Username for terminal access    | `string` | `"wetty"`                         |    no    |
| `wetty_port`        | Port for Wetty service         | `number` | `3000`                            |    no    |

## Outputs

| Name                    | Description                                        |
| ----------------------- | -------------------------------------------------- |
| `wetty_deployment_id`   | The ID of the Wetty deployment resource           |
| `wetty_service_id`      | The ID of the Wetty service resource              |
| `service_name`          | Name of the Wetty service                         |
| `namespace`             | Kubernetes namespace where Wetty is deployed      |
| `service_url`           | Internal service URL for Wetty                    |
| `port_forward_command`  | Command to access Wetty via kubectl port-forward  |

## Requirements

- Kubernetes cluster (tested with Docker Desktop)
- kubectl configured with cluster access
- Terraform kubectl provider

## References

- [Wetty GitHub Repository](https://github.com/butlerx/wetty)
- [Wetty Docker Hub](https://hub.docker.com/r/wettyoss/wetty)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)