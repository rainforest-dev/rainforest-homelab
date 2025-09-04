# Wetty Setup Guide

This guide covers the deployment and usage of Wetty web terminal with Tailscale-only access.

## Quick Start

### 1. Deploy Wetty
```bash
cd /path/to/rainforest-homelab
terraform init
terraform plan
terraform apply
```

### 2. Verify Deployment
```bash
kubectl get pods -n homelab -l app=wetty
kubectl get service -n homelab wetty
```

### 3. Access via Tailscale

#### Find your cluster node IP:
```bash
# Option 1: List Tailscale devices
tailscale status

# Option 2: Get Kubernetes node IPs
kubectl get nodes -o wide

# Option 3: Check from within cluster
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
```

#### Access URLs:
- **Desktop**: `http://<tailscale-node-ip>:30080`
- **Mobile**: Same URL through Tailscale mobile app

## Mobile Access Instructions

### Android/iOS
1. Install Tailscale app from app store
2. Sign in to your Tailscale account
3. Ensure you're connected to the Tailscale network
4. Open browser (Chrome, Safari, etc.)
5. Navigate to: `http://<tailscale-node-ip>:30080`
6. Bookmark for easy access

### Mobile Tips
- Use landscape orientation for better terminal experience
- Consider external Bluetooth keyboard for extended sessions
- Terminal is touch-friendly with virtual keyboard support
- Pinch to zoom if text is too small

## Security Features

✅ **Tailscale-only access** - Not exposed via public Traefik ingress  
✅ **NodePort service** - Direct cluster access without external load balancer  
✅ **Resource limits** - Prevents resource exhaustion  
✅ **Non-root execution** - Runs with restricted privileges  
✅ **Health checks** - Automatic restart if service becomes unhealthy  

## Troubleshooting

### Can't Access from Tailscale
1. Verify Tailscale connectivity: `tailscale status`
2. Check if NodePort is accessible: `telnet <node-ip> 30080`
3. Verify pod is running: `kubectl get pods -n homelab -l app=wetty`

### Pod Won't Start
1. Check logs: `kubectl logs -n homelab -l app=wetty`
2. Verify resources: `kubectl describe pod -n homelab -l app=wetty`
3. Check node resources: `kubectl top nodes`

### Permission Issues
The terminal runs as user ID 1000. If you need different permissions:
1. Modify the `run_as_user` in the deployment
2. Or use a custom Wetty image with different user setup

## Customization

### Change Port
To use a different NodePort:
```hcl
# In modules/wetty/main.tf
node_port = 30081  # Change to desired port
```

### Resource Limits
Adjust CPU/memory limits in `modules/wetty/main.tf`:
```hcl
resources {
  limits = {
    cpu    = "1000m"    # Increase CPU
    memory = "1Gi"      # Increase memory
  }
}
```

### Environment Variables
Add environment variables to the container:
```hcl
env {
  name  = "WETTY_BASE"
  value = "/terminal"
}
```

## Rental-Setup Compatibility

This deployment is designed to be compatible with rental-setup patterns:
- Uses standard Kubernetes manifests (not Helm chart dependencies)
- Follows modular structure with clean separation
- Maintains security by default (Tailscale-only access)
- Includes comprehensive documentation and troubleshooting

## Advanced Configuration

### Custom Authentication
For additional security, consider:
1. Setting up SSH key authentication on the host
2. Using PAM authentication modules
3. Implementing session recording/auditing

### Tailscale ACLs
Example ACL to restrict access:
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:admin"],
      "dst": ["tag:k8s-cluster:30080"]
    }
  ]
}
```

### Alternative Access Methods
If NodePort doesn't work:
1. **Port Forward**: `kubectl port-forward -n homelab service/wetty 3000:3000`
2. **LoadBalancer**: Change service type in main.tf
3. **Ingress**: Add Traefik route (not recommended for security)

For questions or issues, refer to the detailed README in `modules/wetty/README.md`.