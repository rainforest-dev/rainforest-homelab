# Database Initialization Helper Module
# Allows services to self-register their databases with PostgreSQL
# Updated for Kubernetes-native PostgreSQL deployment

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Create Kubernetes Job for database initialization
resource "kubernetes_job" "database_init" {
  count = var.create_database ? 1 : 0
  
  metadata {
    name      = "${var.service_name}-db-init-${var.force_recreate}"
    namespace = var.namespace
    labels = {
      app     = "database-init"
      service = var.service_name
    }
  }
  
  spec {
    template {
      metadata {
        labels = {
          app     = "database-init"
          service = var.service_name
        }
      }
      
      spec {
        restart_policy = "Never"
        
        container {
          name  = "db-init"
          image = "postgres:15-alpine"
          
          env {
            name  = "PGHOST"
            value = var.postgres_host
          }
          
          env {
            name  = "PGPORT"
            value = "5432"
          }
          
          env {
            name  = "PGUSER"
            value = var.postgres_user
          }
          
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = var.postgres_secret_key
              }
            }
          }
          
          env {
            name  = "PGDATABASE"
            value = var.postgres_admin_db
          }
          
          env {
            name  = "TARGET_DATABASE"
            value = var.database_name
          }
          
          env {
            name  = "SERVICE_USER"
            value = var.service_user
          }
          
          env {
            name  = "SERVICE_PASSWORD"
            value = var.service_password
          }
          
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              set -e
              echo "Waiting for PostgreSQL to be ready..."
              
              # Wait for PostgreSQL to be ready
              max_attempts=30
              attempt=0
              
              while [ $attempt -lt $max_attempts ]; do
                if pg_isready -h $PGHOST -p $PGPORT -U $PGUSER > /dev/null 2>&1; then
                  echo "PostgreSQL is ready!"
                  break
                fi
                echo "Attempt $((attempt + 1))/$max_attempts: PostgreSQL not ready yet..."
                sleep 5
                attempt=$((attempt + 1))
              done
              
              if [ $attempt -eq $max_attempts ]; then
                echo "ERROR: PostgreSQL did not become ready within timeout"
                exit 1
              fi
              
              # Create database if it doesn't exist
              echo "Creating database '$TARGET_DATABASE' if it doesn't exist..."
              psql -c "CREATE DATABASE \"$TARGET_DATABASE\" OWNER $PGUSER;" 2>/dev/null || echo "Database '$TARGET_DATABASE' already exists"
              
              # Create service-specific user if specified
              if [ -n "$SERVICE_USER" ] && [ "$SERVICE_USER" != "$PGUSER" ]; then
                echo "Creating service user '$SERVICE_USER' if it doesn't exist..."
                psql -c "CREATE USER \"$SERVICE_USER\" WITH PASSWORD '$SERVICE_PASSWORD';" 2>/dev/null || echo "User '$SERVICE_USER' already exists"
                psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$TARGET_DATABASE\" TO \"$SERVICE_USER\";" || echo "Grant privileges failed"
                
                # Grant comprehensive schema permissions
                echo "Granting schema permissions to '$SERVICE_USER'..."
                PGDATABASE="$TARGET_DATABASE" psql -c "
                  GRANT ALL ON SCHEMA public TO \"$SERVICE_USER\";
                  GRANT CREATE ON SCHEMA public TO \"$SERVICE_USER\";
                  GRANT USAGE ON SCHEMA public TO \"$SERVICE_USER\";
                  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$SERVICE_USER\";
                  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$SERVICE_USER\";
                  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO \"$SERVICE_USER\";
                " || echo "Schema permissions grant failed"
              fi
              
              # Run custom initialization SQL if provided
              if [ -n "${var.init_sql}" ]; then
                echo "Running custom initialization SQL..."
                PGDATABASE="$TARGET_DATABASE" psql -c "${var.init_sql}" || echo "Custom SQL execution failed"
              fi
              
              echo "Database initialization completed for '$TARGET_DATABASE'"
            EOT
          ]
        }
      }
    }
    
    backoff_limit = 3
  }
  
  wait_for_completion = true
  
  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Create ConfigMap to track database initialization status
resource "kubernetes_config_map" "database_status" {
  count = var.create_database ? 1 : 0
  
  metadata {
    name      = "${var.service_name}-db-status"
    namespace = var.namespace
    labels = {
      app     = "database-init"
      service = var.service_name
    }
  }
  
  data = {
    service_name    = var.service_name
    database_name   = var.database_name
    postgres_host   = var.postgres_host
    service_user    = var.service_user
    initialized_at  = timestamp()
    force_recreate  = var.force_recreate
  }
  
  depends_on = [kubernetes_job.database_init]
}