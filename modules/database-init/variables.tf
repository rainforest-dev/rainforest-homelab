variable "service_name" {
  description = "Name of the service requesting database initialization"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL service hostname"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL superuser username"
  type        = string
  default     = "postgres"
}

variable "namespace" {
  description = "Kubernetes namespace for database initialization job"
  type        = string
  default     = "homelab"
}

variable "postgres_admin_db" {
  description = "PostgreSQL admin database name for administrative operations"
  type        = string
  default     = "postgres"
}

variable "create_database" {
  description = "Whether to create the database"
  type        = bool
  default     = true
}

variable "service_user" {
  description = "Optional service-specific database user (if different from postgres user)"
  type        = string
  default     = ""
}

variable "service_password" {
  description = "Password for service-specific user"
  type        = string
  default     = ""
  sensitive   = true
}

variable "init_sql" {
  description = "Custom SQL to run after database creation"
  type        = string
  default     = ""
}

variable "postgres_password" {
  description = "PostgreSQL superuser password (deprecated - use postgres_secret_name instead)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_secret_name" {
  description = "Name of Kubernetes secret containing PostgreSQL credentials"
  type        = string
  default     = ""
}

variable "postgres_secret_key" {
  description = "Key within the secret containing the PostgreSQL password"
  type        = string
  default     = "postgres-password"
}

variable "force_recreate" {
  description = "Force recreation of database initialization (change this value to trigger)"
  type        = string
  default     = "1"
}