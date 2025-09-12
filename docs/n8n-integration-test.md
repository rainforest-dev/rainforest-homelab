# Test Configuration for n8n PostgreSQL and MinIO Integration
# This file can be used to test the n8n module configuration

# To test these changes:
# 1. Create a terraform.tfvars file with valid values:
#    - Set enable_postgresql = true
#    - Set enable_minio = true  
#    - Provide valid cloudflare credentials (or disable tunnel)
#
# 2. Run: terraform plan
#    - Should show n8n configured with database and S3 environment variables
#    - Should show n8n depends on postgresql and minio modules
#
# 3. Run: terraform apply
#    - PostgreSQL should deploy first
#    - MinIO should deploy second  
#    - n8n should deploy with proper environment configuration
#    - MinIO bucket creation job should run
#
# 4. Verify deployment:
#    - Check n8n pod environment variables contain database config
#    - Check n8n pod environment variables contain S3 config
#    - Check MinIO bucket "n8n-storage" exists
#    - Check n8n connects to PostgreSQL (not SQLite)

# Expected environment variables in n8n pod:
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=homelab-postgresql.homelab.svc.cluster.local
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=postgres
# DB_POSTGRESDB_USER=postgres
# DB_POSTGRESDB_PASSWORD=<from secret>
# N8N_DEFAULT_BINARY_DATA_MODE=s3
# N8N_BINARY_DATA_S3_ENDPOINT=http://homelab-minio.homelab.svc.cluster.local:9000
# N8N_BINARY_DATA_S3_BUCKET=n8n-storage
# N8N_BINARY_DATA_S3_ACCESS_KEY=admin
# N8N_BINARY_DATA_S3_SECRET_KEY=<from minio>
# N8N_BINARY_DATA_S3_REGION=us-east-1
# N8N_BINARY_DATA_S3_FORCE_PATH_STYLE=true

# Test Commands:
# kubectl get pods -n homelab | grep n8n
# kubectl describe pod -n homelab homelab-n8n-xxx | grep -A 20 Environment
# kubectl exec -n homelab homelab-minio-xxx -- mc ls minio/
# kubectl logs -n homelab homelab-n8n-xxx | grep -i database