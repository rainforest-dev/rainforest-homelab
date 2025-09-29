# Homelab Backup Strategy

## External Storage Architecture

All critical user data is stored on **Samsung T7 Touch** external drive at:
```
/Volumes/Samsung T7 Touch/homelab-data/
```

## Critical Data (Backed up to External Storage) ✅

### 1. PostgreSQL Database
- **Location**: `postgresql/`
- **Contains**: All service databases (Open WebUI, Flowise, n8n)
- **Type**: Kubernetes manual PV with hostPath
- **Backup**: Real-time via external storage

### 2. MinIO Object Storage  
- **Location**: `minio/`
- **Contains**: S3-compatible object storage buckets
- **Type**: Kubernetes hostPath volume + external bind mount
- **Backup**: Real-time via external storage

### 3. Calibre-Web Library
- **Location**: `calibre-web/`
- **Contains**: Ebook library, metadata, user preferences
- **Type**: Docker bind mount to external storage
- **Backup**: Real-time via external storage

### 4. n8n Workflows
- **Location**: `n8n/`
- **Contains**: Automation workflows, credentials, executions
- **Type**: Docker volume with external directory mapping
- **Backup**: Real-time via external storage

## Non-Critical Data (Local Storage) ⚠️

### Kubernetes Services on hostpath PVCs:
- **Flowise**: AI workflow configurations (10Gi)
- **Open WebUI**: Chat history and configurations (12Gi total)
- **pgAdmin**: Admin tool configurations (2Gi)

These can be recreated easily and don't contain critical user data.

## Backup Commands

### 1. Manual External Drive Backup
```bash
# Sync external storage to another backup location
rsync -av "/Volumes/Samsung T7 Touch/homelab-data/" "/path/to/backup/destination/"
```

### 2. PostgreSQL Database Backup
```bash
# Individual database backup
kubectl exec -n homelab deployment/homelab-postgresql -- pg_dump -U postgres open_webui_db > backup-$(date +%Y%m%d).sql

# Full cluster backup  
kubectl exec -n homelab deployment/homelab-postgresql -- pg_dumpall -U postgres > full-backup-$(date +%Y%m%d).sql
```

### 3. Docker Volume Backup
```bash
# Backup Calibre-Web data (redundant since it's on external storage)
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar czf /backup/calibre-backup-$(date +%Y%m%d).tar.gz -C /data .
```

### 4. MinIO Bucket Backup
```bash
# Using MinIO client (mc)
mc mirror minio/bucket-name /backup/minio/bucket-name/
```

## Recovery Procedures

### 1. PostgreSQL Recovery
```bash
# Restore individual database
kubectl exec -i -n homelab deployment/homelab-postgresql -- psql -U postgres -d open_webui_db < backup-20250929.sql

# Restore full cluster
kubectl exec -i -n homelab deployment/homelab-postgresql -- psql -U postgres -d postgres < full-backup-20250929.sql
```

### 2. Service Data Recovery
Since critical data is on external storage, recovery is automatic when:
1. External drive is reconnected
2. Services are redeployed with Terraform
3. Data appears immediately (no restore needed)

## Monitoring

### External Storage Health
```bash
# Check external drive status
df -h "/Volumes/Samsung T7 Touch/"

# Check data integrity
ls -la "/Volumes/Samsung T7 Touch/homelab-data/"
```

### Service Data Validation
```bash
# PostgreSQL health
kubectl exec -n homelab deployment/homelab-postgresql -- pg_isready

# MinIO health  
kubectl exec -n homelab deployment/homelab-minio -- mc admin info local

# Check service access
curl -I https://pgadmin.rainforest.tools
curl -I https://minio.rainforest.tools
curl -I https://calibre-web.rainforest.tools
```

## Disaster Recovery Plan

### Complete Infrastructure Loss
1. **Reconnect external drive** to new system
2. **Deploy infrastructure**: `terraform apply`
3. **Verify services**: All data automatically restored

### External Drive Failure
1. **Restore from secondary backup** (rsync backup)
2. **Redeploy services** with restored data
3. **Verify database integrity**

### Individual Service Recovery
1. **PostgreSQL**: Restore from SQL dump
2. **MinIO**: Restore from bucket backup
3. **Calibre-Web**: Restore from tar backup
4. **n8n**: Redeploy (workflows preserved on external storage)

## Security Considerations

- **Encryption**: Samsung T7 Touch supports hardware encryption
- **Access Control**: Zero Trust authentication on all services
- **Network**: All traffic via Cloudflare Tunnel (hidden home IP)
- **Passwords**: All generated via Terraform random_password (no hardcoded secrets)

## Backup Schedule Recommendations

- **Daily**: PostgreSQL database dumps (automated)
- **Weekly**: External drive sync to secondary backup
- **Monthly**: Full service configuration backup
- **Before updates**: Manual backup before infrastructure changes

---

**Last Updated**: September 29, 2025
**External Storage**: Samsung T7 Touch (/Volumes/Samsung T7 Touch/homelab-data/)
**Critical Services**: PostgreSQL, MinIO, Calibre-Web, n8n