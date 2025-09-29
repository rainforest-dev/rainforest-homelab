# Example: How Services Self-Register Databases
# This shows the new pattern where each service manages its own database

# Example 1: Open WebUI with Self-Managed Database
module "open_webui_database" {
  source = "../modules/database-init"
  
  service_name            = "open-webui"
  database_name           = "open_webui_db"
  postgres_container_name = module.postgresql_stack[0].postgres_container_name
  postgres_user           = module.postgresql_stack[0].postgres_user
  
  # Optional: Create service-specific user for better security
  service_user     = "open_webui_user"
  service_password = "secure_open_webui_password_2024"
  
  # Custom initialization SQL for Open WebUI
  init_sql = <<-SQL
    -- Create tables for Open WebUI
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "vector" SCHEMA public;
    
    -- Grant permissions for vector operations
    GRANT ALL ON SCHEMA public TO open_webui_user;
    
    -- Log initialization
    INSERT INTO postgres.public.service_db_log (service_name, database_name, initialized_at) 
    VALUES ('open-webui', 'open_webui_db', NOW()) 
    ON CONFLICT DO NOTHING;
  SQL
}

# Example 2: Flowise with Database Self-Registration
module "flowise_database" {
  source = "../modules/database-init"
  
  service_name            = "flowise"
  database_name           = "flowise_db"
  postgres_container_name = module.postgresql_stack[0].postgres_container_name
  postgres_user           = module.postgresql_stack[0].postgres_user
  
  # Flowise can use main postgres user for simplicity
  create_database = true
  
  init_sql = <<-SQL
    -- Flowise-specific initialization
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    COMMENT ON DATABASE flowise_db IS 'Flowise AI workflow database';
  SQL
}

# Example 3: n8n with Database Self-Registration  
module "n8n_database" {
  source = "../modules/database-init"
  
  service_name            = "n8n"
  database_name           = "n8n_db"
  postgres_container_name = module.postgresql_stack[0].postgres_container_name
  postgres_user           = module.postgresql_stack[0].postgres_user
  
  init_sql = <<-SQL
    -- n8n-specific initialization
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    COMMENT ON DATABASE n8n_db IS 'n8n automation workflow database';
  SQL
}

# Example 4: Future Service - Easy to Add
module "future_service_database" {
  source = "../modules/database-init"
  
  service_name            = "my-new-service"
  database_name           = "my_new_service_db"
  postgres_container_name = module.postgresql_stack[0].postgres_container_name
  postgres_user           = module.postgresql_stack[0].postgres_user
  
  # Conditional creation - only if service is enabled
  create_database = var.enable_my_new_service
  
  service_user     = "my_service_user"
  service_password = var.my_service_db_password
}

# How services use the database connection:
locals {
  # Open WebUI connection string
  open_webui_database_url = "postgresql://${module.open_webui_database.database_user}:${module.open_webui_database.service_password}@${module.postgresql_stack[0].postgres_host}:5432/${module.open_webui_database.database_name}"
  
  # Flowise environment variables
  flowise_db_config = {
    DATABASE_TYPE = "postgres"
    DATABASE_HOST = module.postgresql_stack[0].postgres_host
    DATABASE_PORT = "5432"
    DATABASE_NAME = module.flowise_database.database_name
    DATABASE_USER = module.postgresql_stack[0].postgres_user
    DATABASE_PASSWORD = module.postgresql_stack[0].postgres_password
  }
  
  # n8n environment variables
  n8n_db_config = {
    DB_TYPE                = "postgresdb"
    DB_POSTGRESDB_HOST     = module.postgresql_stack[0].postgres_host
    DB_POSTGRESDB_PORT     = "5432" 
    DB_POSTGRESDB_DATABASE = module.n8n_database.database_name
    DB_POSTGRESDB_USER     = module.postgresql_stack[0].postgres_user
    DB_POSTGRESDB_PASSWORD = module.postgresql_stack[0].postgres_password
  }
}

# Service modules can then use these configurations:
module "open_webui_service" {
  source = "../modules/open-webui"
  
  # Service configuration
  project_name = var.project_name
  environment  = var.environment
  
  # Database configuration from self-registered database
  database_url = local.open_webui_database_url
  
  # Wait for database to be ready
  depends_on = [module.open_webui_database]
}