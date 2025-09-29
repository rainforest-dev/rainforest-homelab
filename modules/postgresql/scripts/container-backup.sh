#!/bin/bash
# Simplified PostgreSQL Backup Script for Container Environment
set -e

# Configuration from environment variables
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
NAS_IP="${NAS_IP:-100.84.80.123}"
PROJECT_NAME="${PROJECT_NAME:-homelab}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Create backup directories
mkdir -p "$BACKUP_DIR"/{sql,summary}

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -c '\q' 2>/dev/null; do
    log "PostgreSQL is unavailable - sleeping"
    sleep 5
done
log "PostgreSQL is ready"

# Backup all databases
log "Starting database backup..."
DATABASES=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');")

for db in $DATABASES; do
    db=$(echo "$db" | xargs)  # Trim whitespace
    if [[ -n "$db" ]]; then
        log "Backing up database: $db"
        PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$db" | gzip > "$BACKUP_DIR/sql/${db}_${TIMESTAMP}.sql.gz"
        
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            log "✓ Database $db backed up successfully"
        else
            log "✗ Failed to backup database $db"
        fi
    fi
done

# Create full cluster backup
log "Creating full cluster backup..."
PGPASSWORD="$POSTGRES_PASSWORD" pg_dumpall -h "$POSTGRES_HOST" -U "$POSTGRES_USER" | gzip > "$BACKUP_DIR/sql/full_cluster_${TIMESTAMP}.sql.gz"

if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    log "✓ Full cluster backup completed"
else
    log "✗ Full cluster backup failed"
fi

# Create backup summary
cat > "$BACKUP_DIR/summary/backup_${TIMESTAMP}.txt" << EOF
PostgreSQL Backup Summary
========================
Date: $(date)
Backup ID: $TIMESTAMP
Project: $PROJECT_NAME
Host: $POSTGRES_HOST

Files Created:
$(find "$BACKUP_DIR/sql" -name "*${TIMESTAMP}*" -type f -exec basename {} \; | sort)

Backup Sizes:
$(find "$BACKUP_DIR/sql" -name "*${TIMESTAMP}*" -type f -exec ls -lh {} \; | awk '{print $5 " " $9}')

PostgreSQL Version:
$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -t -c "SELECT version();" 2>/dev/null || echo "Could not connect")

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

log "Backup summary created"

# Sync to NAS if reachable
if ping -c 1 "$NAS_IP" > /dev/null 2>&1; then
    log "Syncing to Synology NAS..."
    rsync -avz --progress "$BACKUP_DIR/" "root@$NAS_IP:/volume1/backups/homelab/postgresql/" 2>/dev/null && \
        log "✓ Backups synced to NAS" || \
        log "✗ NAS sync failed"
else
    log "NAS not reachable, skipping sync"
fi

# Clean up old backups
log "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

log "Backup process completed!"
log "Backup location: $BACKUP_DIR"
log "Backup timestamp: $TIMESTAMP"