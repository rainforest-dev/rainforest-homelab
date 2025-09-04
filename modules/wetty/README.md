# Wetty Web Terminal

This module deploys [Wetty](https://github.com/butlerx/wetty), a web-based terminal emulator, as part of the homelab infrastructure. 

## Security & Access

**Important**: Wetty is configured for **Tailscale-only access** and is **NOT exposed** through the public Traefik ingress. This ensures secure, private access to the terminal interface.

## Deployment Details

- **Namespace**: `homelab`
- **Image**: `wettyoss/wetty:latest`
- **Port**: 3000 (internal), NodePort 30080 (external)
- **Service Type**: NodePort (for Tailscale access)
- **No Traefik IngressRoute**: Intentionally omitted for security

## Accessing Wetty via Tailscale

### Prerequisites
1. Tailscale must be installed and configured on your device
2. The Kubernetes cluster node must be accessible via Tailscale network
3. NodePort 30080 must be accessible from Tailscale clients

### Desktop Access
```bash
# Access via Tailscale IP of the cluster node
http://<tailscale-node-ip>:30080
```

### Mobile Access
1. Install Tailscale mobile app
2. Connect to your Tailscale network
3. Open browser and navigate to: `http://<tailscale-node-ip>:30080`

### Finding Your Cluster Node IP
```bash
# List Tailscale devices to find your cluster node
tailscale status

# Or check from within the cluster
kubectl get nodes -o wide
```

## Configuration

The deployment includes:
- Resource limits: 500m CPU, 512Mi memory
- Security context: runs as non-root user (1000)
- Health checks: liveness and readiness probes
- Fixed NodePort (30080) for consistent access

## Authentication & Security Best Practices

### Recommended Security Measures
1. **Host-level authentication**: Ensure the cluster node requires proper authentication
2. **Tailscale ACLs**: Configure Tailscale Access Control Lists to restrict access
3. **Shell restrictions**: Consider using restricted shells or containerized environments
4. **Audit logging**: Enable shell session logging if required
5. **Regular updates**: Keep the Wetty image updated

### Example Tailscale ACL (policy.json)
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:homelab-admins"],
      "dst": ["tag:homelab-k8s:30080"]
    }
  ],
  "groups": {
    "group:homelab-admins": ["user1@example.com", "user2@example.com"]
  },
  "tagOwners": {
    "tag:homelab-k8s": ["group:homelab-admins"]
  }
}
```

## Troubleshooting

### Check Deployment Status
```bash
kubectl get pods -n homelab -l app=wetty
kubectl get service -n homelab wetty
kubectl describe deployment -n homelab wetty
```

### View Logs
```bash
kubectl logs -n homelab -l app=wetty
```

### Test Connectivity
```bash
# From within the cluster
kubectl port-forward -n homelab service/wetty 3000:3000

# Test local access
curl http://localhost:3000
```

### Common Issues
1. **NodePort not accessible**: Check firewall rules and Tailscale connectivity
2. **Pod not starting**: Check resource constraints and image availability
3. **Authentication issues**: Verify host-level authentication setup

## Alternative Access Methods

If NodePort access doesn't work in your Tailscale setup, consider:

1. **Port forwarding** (temporary access):
   ```bash
   kubectl port-forward -n homelab service/wetty 3000:3000
   ```

2. **LoadBalancer service** (if supported by your cluster):
   ```hcl
   # In main.tf, change service type
   type = "LoadBalancer"
   ```

3. **Tailscale sidecar** (advanced):
   - Deploy a Tailscale sidecar container alongside Wetty
   - Requires Tailscale operator or manual configuration

## Security Considerations

- **No public exposure**: Wetty is intentionally NOT exposed via Traefik
- **Network isolation**: Only accessible via Tailscale network
- **Resource limits**: Configured to prevent resource exhaustion
- **Non-root execution**: Runs with restricted privileges
- **Regular security updates**: Update the wettyoss/wetty image regularly

## Mobile-Friendly Usage

Wetty works well on mobile devices through the Tailscale mobile app:
- Touch-friendly interface
- Virtual keyboard support
- Copy/paste functionality
- Responsive design for small screens

For optimal mobile experience:
- Use landscape orientation
- Consider external keyboard for extended sessions
- Pin the URL in your mobile browser for quick access