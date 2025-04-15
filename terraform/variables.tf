# Variables for SEPTA Station Finder API Terraform configuration

# AWS Settings
variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "aws_deploy" {
  description = "Whether to deploy to AWS"
  type        = bool
  default     = false
}

# Application Settings
variable "environment" {
  description = "Application environment (development, production, etc)"
  type        = string
  default     = "development"
  validation {
    condition     = contains(["development", "production", "staging", "test"], var.environment)
    error_message = "Environment must be one of: development, production, staging, test."
  }
}

variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Logging level"
  type        = string
  default     = "DEBUG"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

# Security
variable "use_generated_secret" {
  description = "Use terraform-generated secret key instead of provided value"
  type        = bool
  default     = true
}

variable "secret_key" {
  description = "JWT secret key (only used if use_generated_secret is false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "algorithm" {
  description = "JWT signing algorithm"
  type        = string
  default     = "HS256"
}

variable "token_expire_mins" {
  description = "JWT token expiration time in minutes"
  type        = number
  default     = 30
}

# Database Configuration
variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "use_generated_db_password" {
  description = "Use terraform-generated PostgreSQL password instead of provided value"
  type        = bool
  default     = true
}

variable "postgres_password" {
  description = "PostgreSQL password (only used if use_generated_db_password is false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "septadb"
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "postgres"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

# Redis Configuration
variable "use_generated_redis_password" {
  description = "Use terraform-generated Redis password instead of provided value"
  type        = bool
  default     = true
}

variable "redis_password" {
  description = "Redis password (only used if use_generated_redis_password is false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_host" {
  description = "Redis host"
  type        = string
  default     = "redis"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

# Docker Configuration

variable "compose_bake" {
  description = "Enable Docker Compose bake feature"
  type        = bool
  default     = true
}

variable "docker_buildkit" {
  description = "Enable Docker BuildKit"
  type        = number
  default     = 1
}

variable "watchfiles_polling" {
  description = "Enable watchfiles force polling"
  type        = bool
  default     = true
}

variable "docker_debug" {
  description = "Enable Docker debug mode"
  type        = number
  default     = 1
}

# Auto Scaling Configuration
variable "min_capacity" {
  description = "Minimum number of tasks for the ECS service"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for the ECS service"
  type        = number
  default     = 10
}

variable "cpu_target_utilization" {
  description = "Target CPU utilization percentage for scaling"
  type        = number
  default     = 70
}

variable "memory_target_utilization" {
  description = "Target memory utilization percentage for scaling"
  type        = number
  default     = 80
}

variable "requests_per_target" {
  description = "Target requests per target for request count based scaling"
  type        = number
  default     = 1000
}

# Output configuration
variable "output_path" {
  description = "Path where to create the .env file"
  type        = string
  default     = ".."
}
