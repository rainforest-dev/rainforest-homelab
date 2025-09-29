#!/bin/bash
# PostgreSQL Backup Script for Synology NAS
set -e

# Configuration
PROJECT_NAME="${PROJECT_NAME:-homelab}"
POSTGRES_CONTAINER="${PROJECT_NAME}-postgresql"
BACKUP_DIR="/Volumes/Samsung T7 Touch/homelab-data/backups"
NAS_IP="100.84.80.123"  # Synology NAS Tailscale IP
NAS_BACKUP_PATH="/volume1/backups/homelab"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if PostgreSQL container is running
check_postgres() {
    if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
        error "PostgreSQL container '$POSTGRES_CONTAINER' is not running"
    fi
    log "PostgreSQL container is running"
}

# Create backup directories
setup_directories() {
    mkdir -p "$BACKUP_DIR"/{sql,files}
    log "Backup directories created"
}

# Backup PostgreSQL databases
backup_databases() {
    log "Starting database backup..."
    
    # Get list of databases (excluding system databases)
    DATABASES=$(docker exec "$POSTGRES_CONTAINER" psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');")
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)  # Trim whitespace
        if [[ -n "$db" ]]; then
            log "Backing up database: $db"
            docker exec "$POSTGRES_CONTAINER" pg_dump -U postgres -h localhost "$db" | gzip > "$BACKUP_DIR/sql/${db}_${TIMESTAMP}.sql.gz"
            
            if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                log "✓ Database $db backed up successfully"
            else
                warn "✗ Failed to backup database $db"
            fi
        fi
    done
    
    # Create a full cluster backup
    log "Creating full cluster backup..."
    docker exec "$POSTGRES_CONTAINER" pg_dumpall -U postgres | gzip > "$BACKUP_DIR/sql/full_cluster_${TIMESTAMP}.sql.gz"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "✓ Full cluster backup completed"
    else
        warn "✗ Full cluster backup failed"
    fi
}

# Backup PostgreSQL data files
backup_files() {
    log "Starting file-level backup..."
    
    # Create tarball of PostgreSQL data directory
    tar -czf "$BACKUP_DIR/files/postgresql_data_${TIMESTAMP}.tar.gz" -C "/Volumes/Samsung T7 Touch/homelab-data" postgresql/
    
    if [[ $? -eq 0 ]]; then
        log "✓ PostgreSQL data files backed up"
    else
        warn "✗ PostgreSQL data files backup failed"
    fi
    
    # Backup pgAdmin data
    if [[ -d "/Volumes/Samsung T7 Touch/homelab-data/pgadmin" ]]; then
        tar -czf "$BACKUP_DIR/files/pgadmin_data_${TIMESTAMP}.tar.gz" -C "/Volumes/Samsung T7 Touch/homelab-data" pgadmin/
        
        if [[ $? -eq 0 ]]; then
            log "✓ pgAdmin data backed up"
        else
            warn "✗ pgAdmin data backup failed"
        fi
    fi
}

# Sync backups to Synology NAS
sync_to_nas() {
    log "Syncing backups to Synology NAS..."
    
    # Check if NAS is reachable via Tailscale
    if ! ping -c 1 "$NAS_IP" > /dev/null 2>&1; then
        warn "Synology NAS ($NAS_IP) is not reachable via Tailscale"
        return 1
    fi
    
    # Sync to NAS using rsync
    rsync -avz --progress "$BACKUP_DIR/" "root@$NAS_IP:$NAS_BACKUP_PATH/postgresql/" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log "✓ Backups synced to Synology NAS"
    else
        warn "✗ Failed to sync backups to NAS (check SSH keys or credentials)"
        return 1
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    # Local cleanup
    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # NAS cleanup (if accessible)
    if ping -c 1 "$NAS_IP" > /dev/null 2>&1; then
        ssh "root@$NAS_IP" "find $NAS_BACKUP_PATH/postgresql -type f -mtime +$RETENTION_DAYS -delete" 2>/dev/null || true
    fi
    
    log "✓ Old backups cleaned up"
}

# Create backup summary
create_summary() {
    SUMMARY_FILE="$BACKUP_DIR/backup_summary_${TIMESTAMP}.txt"
    
    cat > "$SUMMARY_FILE" << EOF
PostgreSQL Backup Summary
========================
Date: $(date)
Backup ID: $TIMESTAMP
Project: $PROJECT_NAME

Files Created:
$(find "$BACKUP_DIR" -name "*${TIMESTAMP}*" -type f -exec basename {} \; | sort)

Backup Sizes:
$(find "$BACKUP_DIR" -name "*${TIMESTAMP}*" -type f -exec ls -lh {} \; | awk '{print $5 " " $9}')

PostgreSQL Status:
$(docker exec "$POSTGRES_CONTAINER" psql -U postgres -c "SELECT version();" 2>/dev/null || echo "Could not connect")

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

    log "Backup summary created: $SUMMARY_FILE"
}

# Verify backups
verify_backups() {
    log "Verifying backup integrity..."
    
    # Check if SQL backups can be read
    for sql_backup in "$BACKUP_DIR/sql"/*${TIMESTAMP}.sql.gz; do
        if [[ -f "$sql_backup" ]]; then
            if gzip -t "$sql_backup" 2>/dev/null; then
                log "✓ SQL backup $(basename "$sql_backup") is valid"
            else
                warn "✗ SQL backup $(basename "$sql_backup") is corrupted"
            fi
        fi
    done
    
    # Check if file backups can be read
    for file_backup in "$BACKUP_DIR/files"/*${TIMESTAMP}.tar.gz; do
        if [[ -f "$file_backup" ]]; then
            if tar -tzf "$file_backup" > /dev/null 2>&1; then
                log "✓ File backup $(basename "$file_backup") is valid"
            else
                warn "✗ File backup $(basename "$file_backup") is corrupted"
            fi
        fi
    done
}

# Main execution
main() {
    log "Starting PostgreSQL backup process..."
    
    check_postgres
    setup_directories
    backup_databases
    backup_files
    verify_backups
    create_summary
    
    # Try to sync to NAS (non-blocking)
    sync_to_nas || warn "NAS sync failed, backups are still available locally"
    
    cleanup_old_backups
    
    log "Backup process completed successfully!"
    log "Backup location: $BACKUP_DIR"
    log "Backup timestamp: $TIMESTAMP"
}

# Handle script arguments
case "${1:-backup}" in
    backup)
        main
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    verify)
        verify_backups
        ;;
    sync)
        sync_to_nas
        ;;
    *)
        echo "Usage: $0 [backup|cleanup|verify|sync]"
        echo "  backup  - Perform full backup (default)"
        echo "  cleanup - Clean up old backups"
        echo "  verify  - Verify backup integrity"
        echo "  sync    - Sync to NAS only"
        exit 1
        ;;
esac