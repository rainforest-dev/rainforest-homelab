# Homelab Service Upgrade Standard Operating Procedure (SOP)

## Overview

This document provides safe procedures for manually upgrading homelab services. The `./upgrade` script only **checks** for available updates - all upgrades must be performed manually for safety.

## Quick Reference

```bash
# Check what needs upgrading
./upgrade

# Get manual upgrade commands
./upgrade manual
```

## Pre-Upgrade Checklist

### 1. Backup Data ✅
```bash
# Backup Docker volumes
cd automation
./backup-volumes.sh

# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
```

### 2. Check Service Health ✅
```bash
kubectl get pods -n homelab
kubectl get services -n homelab
docker ps
```

### 3. Review Available Updates ✅
```bash
./upgrade check
```

## Upgrade Procedures by Service Type

### Helm Chart Services (open-webui, flowise, homepage)

**Example: Upgrading flowise from 5.1.1 → 6.0.0**

1. **Update main.tf**
   ```bash
   # Option A: Update existing version
   sed -i '' '/module "flowise" {/,/^}/{s/chart_version = "[^"]*"/chart_version = "6.0.0"/}' main.tf
   
   # Option B: Add version if not present
   # Edit main.tf and add: chart_version = "6.0.0" to the flowise module block
   ```

2. **Plan and Review**
   ```bash
   terraform plan -target="module.flowise"
   # Review all changes carefully
   ```

3. **Apply Upgrade**
   ```bash
   terraform apply -target="module.flowise"
   ```

4. **Verify Service**
   ```bash
   kubectl get pods -n homelab -l app.kubernetes.io/name=flowise
   kubectl logs -n homelab -l app.kubernetes.io/name=flowise --tail=20
   # Test service at https://flowise.yourdomain.com
   ```

### OCI Helm Services (postgresql, n8n)

**Example: Upgrading n8n**

1. **Check Latest Version**
   - PostgreSQL: https://hub.docker.com/r/bitnami/postgresql/tags
   - n8n: https://github.com/n8n-io/n8n/releases

2. **Force Helm Release Recreation**
   ```bash
   terraform apply -replace="module.n8n.helm_release.n8n" -auto-approve
   ```

3. **Verify Service**
   ```bash
   kubectl get pods -n homelab -l app.kubernetes.io/name=n8n
   kubectl logs -n homelab -l app.kubernetes.io/name=n8n --tail=20
   # Test service at https://n8n.yourdomain.com
   ```

### Docker Services (calibre-web)

**Example: Upgrading calibre-web**

1. **Force Container Recreation**
   ```bash
   terraform apply -replace="module.calibre-web.docker_container.calibre-web" -auto-approve
   ```

2. **Verify Service**
   ```bash
   docker ps | grep calibre-web
   docker logs homelab-calibre-web --tail=20
   # Test service at http://localhost:8083
   ```

## Troubleshooting Common Issues

### Kubernetes "Immutable Field" Errors

**Problem**: `spec.selector: Invalid value... field is immutable`

**Solution**: Force recreation of the helm release
```bash
terraform apply -replace="module.SERVICE_NAME.helm_release.SERVICE_NAME" -auto-approve
```

### Service Won't Start After Upgrade

**Diagnosis**:
```bash
kubectl describe pod -n homelab -l app.kubernetes.io/name=SERVICE_NAME
kubectl logs -n homelab -l app.kubernetes.io/name=SERVICE_NAME
```

**Common Solutions**:
1. **Configuration Issues**: Check if new version requires config changes
2. **Resource Limits**: Increase CPU/memory limits in Terraform
3. **Persistence Issues**: Check if data migration is needed

### Rollback Procedures

**Helm Services**:
```bash
# Rollback to previous chart version
helm rollback -n homelab RELEASE_NAME
# Then update main.tf with previous version
```

**Docker Services**:
```bash
# Use specific image tag instead of latest
# Edit variables.tf to pin image_tag to known good version
terraform apply -target="module.SERVICE_NAME"
```

## Service-Specific Notes

### PostgreSQL
- ⚠️ **Database Upgrades**: Major version upgrades may require data migration
- 🔒 **Backup First**: Always backup database before upgrading
- 📖 **Check Release Notes**: Review PostgreSQL release notes for breaking changes

### n8n
- 🔄 **Workflow Compatibility**: Test workflows after upgrade
- 📊 **Database Migration**: May require automatic database migrations
- 🔑 **Environment Variables**: Check if new version requires new env vars

### Open WebUI
- 🤖 **Model Compatibility**: Verify Ollama/API compatibility
- 👤 **User Sessions**: Users may need to re-login after upgrade
- 🎨 **UI Changes**: Interface may change between versions

### Flowise
- 🔗 **Flow Compatibility**: Test existing flows after upgrade
- 📁 **Node Updates**: New version may have updated/new nodes
- 💾 **Database Schema**: May require automatic migrations

### Homepage
- 📋 **Config Format**: Check if dashboard config format changed
- 🔌 **Widget Updates**: New version may have updated widgets
- 🎯 **Service Discovery**: Verify all services still appear correctly

### Calibre Web
- 📚 **Library Compatibility**: Verify book library access
- 👤 **User Database**: Check if user accounts are preserved
- 🔧 **Config Migration**: May need to update configuration files

## Safety Best Practices

### 1. Staging Environment
- Test upgrades in a separate environment first
- Use Docker Desktop to create isolated test cluster

### 2. Incremental Upgrades
- Upgrade one service at a time
- Wait for service to stabilize before next upgrade
- Don't upgrade multiple services simultaneously

### 3. Monitoring
```bash
# Monitor service health during upgrade
watch "kubectl get pods -n homelab"

# Check resource usage
kubectl top pods -n homelab
kubectl top nodes
```

### 4. Documentation
- Keep upgrade log with versions and dates
- Document any custom configurations or workarounds
- Note any breaking changes encountered

## Emergency Procedures

### Complete Service Failure
1. **Stop all traffic**: Update Cloudflare tunnel to maintenance page
2. **Restore from backup**: Use volume backups to restore data
3. **Rollback**: Revert to last known good configuration
4. **Debug**: Investigate issues in isolated environment

### Data Corruption
1. **Immediately stop service**: `kubectl scale deployment SERVICE_NAME --replicas=0`
2. **Restore from backup**: Mount backup volumes
3. **Verify data integrity**: Check database/files before restart
4. **Document incident**: Note cause and prevention measures

## Maintenance Schedule

### Weekly
- Check for available updates: `./upgrade check`
- Review service health and logs
- Update documentation with any changes

### Monthly
- Plan and execute non-critical upgrades
- Review and test backup procedures
- Update this SOP with new learnings

### Quarterly
- Major version upgrades (with careful planning)
- Security-focused upgrades
- Infrastructure and tooling updates

---

## Quick Commands Reference

```bash
# Version checking
./upgrade                    # Check all versions
./upgrade manual            # Get manual upgrade commands

# Backup procedures
docker volume ls --filter label=project=homelab
docker run --rm -v VOLUME_NAME:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz -C /data .

# Service management
kubectl get pods -n homelab                    # Check pod status
kubectl logs -n homelab -l app=SERVICE_NAME   # Check logs
kubectl describe pod -n homelab POD_NAME      # Debug pod issues

# Terraform operations
terraform plan -target="module.SERVICE_NAME"  # Review changes
terraform apply -target="module.SERVICE_NAME" # Apply changes
terraform apply -replace="RESOURCE_ADDRESS"   # Force recreation

# Cloudflare tunnel
kubectl logs -n homelab -l app=cloudflared    # Check tunnel logs
kubectl get configmap -n homelab cloudflared-config -o yaml  # View config
```

**Remember**: Safety first! Always plan, backup, and test upgrades carefully. 🛡️