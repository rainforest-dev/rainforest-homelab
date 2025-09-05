# Wetty Web Terminal - Usage Guide

This guide explains how to deploy and access the Wetty web terminal in your homelab infrastructure.

## Quick Start

### 1. Enable Wetty

Edit your `terraform.tfvars` file:

```hcl
# Enable Wetty web terminal
enable_wetty = true
```

### 2. Deploy

```bash
terraform apply
```

### 3. Access via Port Forward

```bash
# Forward port to access Wetty
kubectl port-forward -n homelab service/homelab-wetty 3000:3000

# Open in browser
open http://localhost:3000
```

## Mobile Access via Tailscale

If your Kubernetes cluster host is connected to Tailscale:

### Option 1: Using Tailscale IP

```bash
# On your cluster host, set up port forwarding
kubectl port-forward -n homelab service/homelab-wetty 3000:3000

# From any Tailscale device, find the host IP
tailscale ip

# Access via browser (replace with your actual IP)
http://100.x.x.x:3000
```

### Option 2: Using MagicDNS (Recommended)

```bash
# Set up port forwarding on cluster host
kubectl port-forward -n homelab service/homelab-wetty 3000:3000

# Access from any Tailscale device using machine name
http://your-machine-name:3000
```

## Login Credentials

- **Username**: `terminal`
- **Password**: `wetty123`

⚠️ **Security Note**: Change the default password for production use!

## Advanced Configuration

### Custom Resource Limits

```hcl
module "wetty" {
  source = "./modules/wetty"
  
  cpu_limit    = "500m"
  memory_limit = "512Mi"
  wetty_user   = "admin"
  wetty_port   = 8080
}
```

### Persistent Storage (Optional)

```hcl
module "wetty" {
  source = "./modules/wetty"
  
  enable_persistence = true
  storage_size       = "5Gi"
}
```

## Security Best Practices

### 1. Change Default Password

Connect to the Wetty container and change the password:

```bash
# Port forward to access wetty
kubectl port-forward -n homelab service/homelab-wetty 3000:3000

# In another terminal, exec into the container
kubectl exec -it -n homelab deployment/homelab-wetty -- /bin/bash

# Change password for the terminal user
passwd terminal
```

### 2. SSH Key Authentication (Advanced)

For enhanced security, set up SSH key authentication:

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/wetty_key

# Create Kubernetes secret with public key
kubectl create secret generic wetty-ssh-keys \
  --from-file=authorized_keys=~/.ssh/wetty_key.pub \
  -n homelab

# Private key stays on your local machine at ~/.ssh/wetty_key
```

### 3. Network Security

Wetty is configured with:
- ✅ Internal ClusterIP service only
- ✅ No external ingress or load balancer
- ✅ No Cloudflare Tunnel exposure
- ✅ Resource limits enforced
- ✅ Security contexts applied

## Troubleshooting

### Wetty Not Starting

Check pod status:
```bash
kubectl get pods -n homelab -l app=homelab-wetty
kubectl describe pod -n homelab -l app=homelab-wetty
```

Check logs:
```bash
kubectl logs -n homelab -l app=homelab-wetty -f
```

### Cannot Access Terminal

1. **Check port forward is running**:
   ```bash
   ps aux | grep "kubectl port-forward"
   ```

2. **Check service is accessible**:
   ```bash
   kubectl get svc -n homelab homelab-wetty
   ```

3. **Test connection inside cluster**:
   ```bash
   kubectl run test-pod --rm -i --tty --image=busybox -- /bin/sh
   # Inside the pod:
   wget -qO- http://homelab-wetty.homelab.svc.cluster.local:3000
   ```

### Permission Issues

If you get permission errors in the terminal:

```bash
# Check if user was created properly
kubectl exec -it -n homelab deployment/homelab-wetty -- id terminal

# Check home directory permissions
kubectl exec -it -n homelab deployment/homelab-wetty -- ls -la /home/
```

## Uninstalling

To remove Wetty:

```hcl
# In terraform.tfvars
enable_wetty = false
```

```bash
terraform apply
```

## Integration with Homepage

Wetty will appear in your Homepage dashboard automatically with internal access instructions.

## Mobile Terminal Apps

For the best mobile experience, consider these apps that work well with Wetty:

- **iOS**: Safari, Chrome, or terminal apps that support web connections
- **Android**: Chrome, Firefox, or Termux with web browser
- **iPad**: Safari with desktop mode for better terminal experience

## Performance Considerations

- Default resource limits are conservative (200m CPU, 256Mi memory)
- Increase limits for heavy terminal usage
- Consider enabling persistence for permanent file storage
- Multiple users can share the same Wetty instance