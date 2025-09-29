# Database Initialization Helper Module
# Allows services to self-register their databases with PostgreSQL

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Wait for PostgreSQL to be ready and create database
resource "null_resource" "database_init" {
  # Only run if database creation is enabled
  count = var.create_database ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for PostgreSQL to be ready
      echo "Waiting for PostgreSQL to be ready..."
      max_attempts=30
      attempt=0
      
      while [ $attempt -lt $max_attempts ]; do
        if docker exec ${var.postgres_container_name} pg_isready -U ${var.postgres_user} > /dev/null 2>&1; then
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
      echo "Creating database '${var.database_name}' if it doesn't exist..."
      docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.postgres_admin_db} -c "
        SELECT 'Database already exists' WHERE EXISTS (SELECT FROM pg_database WHERE datname = '${var.database_name}')
        UNION ALL
        SELECT 'Creating database' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${var.database_name}');
      " || true
      
      docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.postgres_admin_db} -c "
        CREATE DATABASE \"${var.database_name}\" OWNER ${var.postgres_user};
      " 2>/dev/null || echo "Database '${var.database_name}' already exists or creation failed"
      
      # Create service-specific user if specified
      if [ -n "${var.service_user}" ] && [ "${var.service_user}" != "${var.postgres_user}" ]; then
        echo "Creating service user '${var.service_user}' if it doesn't exist..."
        docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.postgres_admin_db} -c "
          CREATE USER \"${var.service_user}\" WITH PASSWORD '${var.service_password}';
          GRANT ALL PRIVILEGES ON DATABASE \"${var.database_name}\" TO \"${var.service_user}\";
        " 2>/dev/null || echo "User '${var.service_user}' already exists or creation failed"
        
        # Grant comprehensive schema permissions
        echo "Granting schema permissions to '${var.service_user}'..."
        docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.database_name} -c "
          GRANT ALL ON SCHEMA public TO \"${var.service_user}\";
          GRANT CREATE ON SCHEMA public TO \"${var.service_user}\";
          GRANT USAGE ON SCHEMA public TO \"${var.service_user}\";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"${var.service_user}\";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"${var.service_user}\";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO \"${var.service_user}\";
        " || echo "Schema permissions grant failed"
      fi
      
      # Run custom initialization SQL if provided
      if [ -n "${var.init_sql}" ]; then
        echo "Running custom initialization SQL..."
        docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.database_name} -c "${var.init_sql}" || echo "Custom SQL execution failed"
      fi
      
      echo "Database initialization completed for '${var.database_name}'"
    EOT
  }

  # Trigger re-creation if key parameters change
  triggers = {
    database_name           = var.database_name
    postgres_container_name = var.postgres_container_name
    service_user           = var.service_user
    init_sql_hash          = md5(var.init_sql)
    force_recreate         = var.force_recreate
  }
}

# Create database initialization status tracking
resource "null_resource" "database_status" {
  count = var.create_database ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      # Log database creation status
      echo "$(date): Database '${var.database_name}' initialized for service '${var.service_name}'" >> /tmp/homelab-db-init.log
      
      # Verify database exists
      docker exec ${var.postgres_container_name} psql -U ${var.postgres_user} -d ${var.database_name} -c "
        SELECT 
          '${var.service_name}' as service_name,
          '${var.database_name}' as database_name,
          current_database() as connected_db,
          current_user as current_user,
          version() as postgres_version,
          now() as initialized_at;
      " || echo "Database verification failed"
    EOT
  }

  depends_on = [null_resource.database_init]
}