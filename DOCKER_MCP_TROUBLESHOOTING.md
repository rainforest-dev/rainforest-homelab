# Docker MCP Gateway Troubleshooting Guide

This guide covers common issues and solutions for Docker MCP Gateway deployment and operation.

## Quick Diagnostics

### Health Check Commands
```bash
# Check pod status
kubectl get pods -n homelab -l app=docker-mcp-gateway

# View pod logs
kubectl logs -n homelab -l app=docker-mcp-gateway -f

# Check service endpoints
kubectl get endpoints -n homelab homelab-docker-mcp-gateway

# Test internal connectivity
kubectl run test-pod --rm -it --restart=Never --image=alpine -- \
  wget -qO- http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080/health
```

### External Access Tests
```bash
# Test DNS resolution
dig docker-mcp.yourdomain.com

# Test external connectivity
curl -v https://docker-mcp.yourdomain.com/health

# Check Cloudflare Tunnel status
kubectl logs -n homelab -l app=cloudflared --tail=50
```

## Common Issues and Solutions

### 1. Pod Won't Start

#### Symptoms
- Pod stuck in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff`
- Events show scheduling or image pull failures

#### Diagnostics
```bash
# Check pod details
kubectl describe pod -n homelab -l app=docker-mcp-gateway

# Check node resources
kubectl top nodes

# Check events
kubectl get events -n homelab --sort-by='.lastTimestamp' | grep docker-mcp
```

#### Solutions

**Image Pull Issues:**
```bash
# Verify image exists
docker pull alpine:3.19

# Check if using custom image
kubectl get deployment -n homelab homelab-docker-mcp-gateway -o yaml | grep image:

# Update to working image
kubectl patch deployment -n homelab homelab-docker-mcp-gateway \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"docker-mcp-gateway","image":"alpine:3.19"}]}}}}'
```

**Resource Issues:**
```bash
# Check resource limits
kubectl get deployment -n homelab homelab-docker-mcp-gateway -o yaml | grep -A 10 resources:

# Reduce resource requirements (temporary)
kubectl patch deployment -n homelab homelab-docker-mcp-gateway \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"docker-mcp-gateway","resources":{"limits":{"cpu":"200m","memory":"256Mi"}}}]}}}}'
```

### 2. Docker Socket Permission Denied

#### Symptoms
- Logs show "permission denied" when accessing Docker socket
- Container starts but can't execute Docker commands

#### Diagnostics
```bash
# Check Docker socket permissions on host
ls -la /var/run/docker.sock

# Check security context in pod
kubectl get pod -n homelab -l app=docker-mcp-gateway -o yaml | grep -A 10 securityContext

# Test socket access in pod
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- \
  ls -la /var/run/docker.sock
```

#### Solutions

**Fix Socket Permissions:**
```bash
# On Docker Desktop, ensure socket is accessible
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group
sudo usermod -aG docker $USER
```

**Update Security Context:**
```yaml
# Add to deployment via kubectl patch
kubectl patch deployment -n homelab homelab-docker-mcp-gateway \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "securityContext": {
            "fsGroup": 999
          },
          "containers": [{
            "name": "docker-mcp-gateway",
            "securityContext": {
              "runAsUser": 0,
              "runAsGroup": 999
            }
          }]
        }
      }
    }
  }'
```

### 3. External Access Not Working

#### Symptoms
- Internal access works but external URL times out
- Browser shows "connection refused" or SSL errors
- Cloudflare shows 502 Bad Gateway

#### Diagnostics
```bash
# Test internal service
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 8080:8080 &
curl http://localhost:8080/health

# Check tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml

# Check tunnel logs
kubectl logs -n homelab -l app=cloudflared -f

# Verify DNS records
dig docker-mcp.yourdomain.com
```

#### Solutions

**Missing Tunnel Configuration:**
```bash
# Check if ingress rule exists
kubectl get configmap -n homelab cloudflared-config -o yaml | grep docker-mcp

# If missing, add manually (temporary)
kubectl patch configmap -n homelab cloudflared-config \
  --patch-file=/dev/stdin <<EOF
data:
  config.yaml: |
    # ... existing config ...
    ingress:
      - hostname: docker-mcp.yourdomain.com
        service: http://homelab-docker-mcp-gateway.homelab.svc.cluster.local:8080
      # ... other rules ...
EOF
```

**DNS Record Issues:**
- Check Cloudflare DNS records in dashboard
- Ensure record points to tunnel CNAME
- Verify domain is proxied through Cloudflare

**Service Port Mismatch:**
```bash
# Check service port
kubectl get svc -n homelab homelab-docker-mcp-gateway

# Update if incorrect
kubectl patch svc -n homelab homelab-docker-mcp-gateway \
  -p '{"spec":{"ports":[{"port":8080,"targetPort":8080}]}}'
```

### 4. Docker MCP Commands Failing

#### Symptoms
- Service responds to health checks but MCP commands fail
- Logs show "command not found" or parsing errors

#### Diagnostics
```bash
# Check if Docker CLI is installed in container
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- which docker

# Test Docker connectivity
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- docker version

# Check MCP gateway process
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- ps aux | grep mcp
```

#### Solutions

**Install Docker CLI:**
```bash
# Update deployment to install Docker CLI
kubectl patch deployment -n homelab homelab-docker-mcp-gateway \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "docker-mcp-gateway",
            "command": ["/bin/sh"],
            "args": ["-c", "apk add --no-cache docker-cli && exec docker mcp gateway run --config /config/config.json --listen 0.0.0.0:8080"]
          }]
        }
      }
    }
  }'
```

**Alternative with Custom Image:**
```dockerfile
# Build custom image with Docker CLI
FROM alpine:3.19
RUN apk add --no-cache docker-cli curl
COPY docker-mcp-gateway /usr/local/bin/
EXPOSE 8080
CMD ["docker-mcp-gateway", "run"]
```

### 5. Authentication Issues

#### Symptoms
- Can access service but authentication doesn't work
- Gets stuck on authentication page
- "Access Denied" errors

#### Diagnostics
```bash
# Check Zero Trust application configuration
# (Must be done in Cloudflare dashboard)

# Test without authentication
curl -v https://docker-mcp.yourdomain.com/health

# Check for authentication headers
curl -v -H "CF-Access-Authenticated-User-Email: test@yourdomain.com" \
  https://docker-mcp.yourdomain.com/health
```

#### Solutions

**Configure Zero Trust Application:**
1. Go to Cloudflare Dashboard → Zero Trust → Access → Applications
2. Add application for `docker-mcp.yourdomain.com`
3. Set authentication policy:
   ```
   Policy Name: Docker MCP Access
   Include: Email domain is yourdomain.com
   ```

**Update Terraform Configuration:**
```hcl
# In terraform.tfvars
allowed_email_domains = ["yourdomain.com"]
allowed_emails        = ["admin@yourdomain.com"]
```

**Clear Authentication State:**
- Clear browser cookies for `*.yourdomain.com`
- Try incognito/private browsing
- Check email domain configuration

### 6. Performance Issues

#### Symptoms
- Slow response times
- Timeouts on Docker operations
- High CPU/memory usage

#### Diagnostics
```bash
# Check resource usage
kubectl top pods -n homelab -l app=docker-mcp-gateway

# Check resource limits
kubectl describe pod -n homelab -l app=docker-mcp-gateway | grep -A 10 Limits

# Monitor logs for performance issues
kubectl logs -n homelab -l app=docker-mcp-gateway -f | grep -i "slow\|timeout\|error"
```

#### Solutions

**Increase Resources:**
```bash
# Update resource limits
kubectl patch deployment -n homelab homelab-docker-mcp-gateway \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "docker-mcp-gateway",
            "resources": {
              "limits": {
                "cpu": "1000m",
                "memory": "1Gi"
              },
              "requests": {
                "cpu": "200m",
                "memory": "256Mi"
              }
            }
          }]
        }
      }
    }
  }'
```

**Scale Horizontally:**
```bash
# Increase replica count
kubectl scale deployment -n homelab homelab-docker-mcp-gateway --replicas=3
```

### 7. Configuration Issues

#### Symptoms
- Service starts but behaves incorrectly
- Wrong endpoints or missing features
- Configuration validation errors

#### Diagnostics
```bash
# Check configuration map
kubectl get configmap -n homelab homelab-docker-mcp-config -o yaml

# Verify mounted configuration
kubectl exec -n homelab deployment/homelab-docker-mcp-gateway -- \
  cat /config/config.json
```

#### Solutions

**Update Configuration:**
```bash
# Update config map
kubectl patch configmap -n homelab homelab-docker-mcp-config \
  --patch-file=/dev/stdin <<EOF
data:
  config.json: |
    {
      "server": {
        "name": "docker-mcp-gateway",
        "version": "1.0.0"
      },
      "logging": {
        "level": "debug"
      },
      "docker": {
        "socket_path": "/var/run/docker.sock",
        "timeout": 60
      }
    }
EOF

# Restart deployment to pick up new config
kubectl rollout restart deployment -n homelab homelab-docker-mcp-gateway
```

## Recovery Procedures

### Complete Reset
```bash
# Delete all resources
kubectl delete deployment,service,configmap,serviceaccount \
  -n homelab -l app=docker-mcp-gateway

# Redeploy with Terraform
terraform apply -target="module.docker_mcp_gateway"
```

### Rollback to Previous Version
```bash
# Check rollout history
kubectl rollout history deployment -n homelab homelab-docker-mcp-gateway

# Rollback to previous version
kubectl rollout undo deployment -n homelab homelab-docker-mcp-gateway

# Or rollback to specific revision
kubectl rollout undo deployment -n homelab homelab-docker-mcp-gateway --to-revision=2
```

### Emergency Access
```bash
# Port forward for direct access
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 8080:8080

# Or create temporary NodePort service
kubectl patch svc -n homelab homelab-docker-mcp-gateway \
  -p '{"spec":{"type":"NodePort","ports":[{"nodePort":30080,"port":8080}]}}'
```

## Monitoring and Alerting

### Health Monitoring
```bash
# Create monitoring script
#!/bin/bash
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://docker-mcp.yourdomain.com/health)
  if [ "$STATUS" != "200" ]; then
    echo "$(date): Health check failed with status $STATUS"
    # Add alerting logic here
  fi
  sleep 60
done
```

### Log Monitoring
```bash
# Monitor for errors
kubectl logs -n homelab -l app=docker-mcp-gateway -f | \
  grep -i "error\|fail\|exception" | \
  while read line; do
    echo "$(date): ERROR: $line"
    # Add alerting logic here
  done
```

## Support Contacts

For additional assistance:

1. **Terraform Issues**: Check module documentation and Terraform logs
2. **Kubernetes Issues**: Review cluster status and resource constraints  
3. **Cloudflare Issues**: Check tunnel status and DNS configuration
4. **Docker Issues**: Verify socket permissions and Docker CLI availability
5. **Authentication Issues**: Review Zero Trust configuration and policies

## Useful Commands Reference

```bash
# Quick status check
kubectl get all -n homelab -l app=docker-mcp-gateway

# Get full deployment YAML
kubectl get deployment -n homelab homelab-docker-mcp-gateway -o yaml

# Watch pod events
kubectl get events -n homelab --watch | grep docker-mcp

# Interactive debugging
kubectl exec -it -n homelab deployment/homelab-docker-mcp-gateway -- /bin/sh

# Port forward for testing
kubectl port-forward -n homelab svc/homelab-docker-mcp-gateway 8080:8080

# Check resource usage over time
watch kubectl top pods -n homelab -l app=docker-mcp-gateway
```