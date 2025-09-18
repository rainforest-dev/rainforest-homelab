# n8n Configuration with PostgreSQL and MinIO

This module configures n8n to use centralized PostgreSQL for database storage and MinIO for file attachments and node data storage.

## Overview

- **Database**: Uses centralized PostgreSQL instead of local SQLite
- **File Storage**: Uses MinIO S3-compatible storage for binary data and attachments
- **Dependencies**: Requires PostgreSQL and MinIO modules to be enabled

## Configuration

### Database Configuration

When `enable_external_database = true`, n8n will be configured to use PostgreSQL:

- **DB_TYPE**: Set to `postgresdb`
- **DB_POSTGRESDB_HOST**: PostgreSQL service hostname
- **DB_POSTGRESDB_PORT**: PostgreSQL port (default: 5432)
- **DB_POSTGRESDB_DATABASE**: Database name (default: postgres)
- **DB_POSTGRESDB_USER**: Database user (default: postgres)
- **DB_POSTGRESDB_PASSWORD**: Retrieved from PostgreSQL secret

### S3/MinIO Configuration

When `enable_s3_storage = true`, n8n will use MinIO for file storage:

- **N8N_DEFAULT_BINARY_DATA_MODE**: Set to `s3`
- **N8N_BINARY_DATA_S3_ENDPOINT**: MinIO service endpoint
- **N8N_BINARY_DATA_S3_BUCKET**: S3 bucket name (default: n8n-storage)
- **N8N_BINARY_DATA_S3_ACCESS_KEY**: MinIO access key
- **N8N_BINARY_DATA_S3_SECRET_KEY**: MinIO secret key
- **N8N_BINARY_DATA_S3_FORCE_PATH_STYLE**: Set to `true` for MinIO compatibility

## Bucket Creation

The module includes an automatic bucket creation job that:
- Runs when S3 storage is enabled
- Creates the n8n storage bucket if it doesn't exist
- Uses MinIO client (mc) to ensure bucket availability

## Dependencies

The n8n module depends on:
- PostgreSQL module (when database integration is enabled)
- MinIO module (when S3 storage is enabled)

## Migration Notes

### From SQLite to PostgreSQL

When enabling external database for existing n8n deployments:
1. n8n will automatically migrate data from SQLite to PostgreSQL on first startup
2. Ensure PostgreSQL is available before n8n starts
3. Monitor n8n logs for migration progress

### File Storage Migration

When enabling S3 storage:
1. Existing files in persistent volumes will remain accessible
2. New binary data will be stored in MinIO
3. Consider migrating existing files manually if needed

## Security

- Database passwords are retrieved from Kubernetes secrets
- MinIO credentials are passed securely through environment variables
- All sensitive values are marked appropriately in Terraform