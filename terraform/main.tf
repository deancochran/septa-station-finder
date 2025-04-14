# Main Terraform configuration file for SEPTA Station Finder API

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "random" {}
provider "local" {}
provider "aws" {
  region = var.aws_region
}

# Generate a secure random key for JWT signing
resource "random_id" "secret_key" {
  byte_length = 32
}

# Generate a secure password for PostgreSQL
resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate a secure password for Redis
resource "random_password" "redis_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create the .env file using all variables
resource "local_file" "env_file" {
  content = templatefile("${path.module}/templates/env.tftpl", {
    # Application Settings
    environment = var.environment
    debug       = var.debug
    log_level   = var.log_level

    # Security
    secret_key        = var.use_generated_secret ? random_id.secret_key.hex : var.secret_key
    algorithm         = var.algorithm
    token_expire_mins = var.token_expire_mins

    # Database Configuration
    postgres_user     = var.postgres_user
    postgres_password = var.use_generated_db_password ? random_password.postgres_password.result : var.postgres_password
    postgres_db       = var.postgres_db
    postgres_host     = var.postgres_host
    postgres_port     = var.postgres_port

    # Redis Configuration
    redis_password = var.use_generated_redis_password ? random_password.redis_password.result : var.redis_password
    redis_host     = var.redis_host
    redis_port     = var.redis_port

    # Docker Configuration
    docker_username    = var.docker_username
    docker_password    = var.docker_password
    compose_bake       = var.compose_bake
    docker_buildkit    = var.docker_buildkit
    watchfiles_polling = var.watchfiles_polling
    docker_debug       = var.docker_debug
  })
  filename = "${var.output_path}/.env"
}

# Output important information
output "env_file_path" {
  value       = local_file.env_file.filename
  description = "Path to the generated .env file"
}

output "environment" {
  value       = var.environment
  description = "The environment this deployment is configured for"
}

output "postgres_user" {
  value       = var.postgres_user
  description = "PostgreSQL username"
}

output "postgres_db" {
  value       = var.postgres_db
  description = "PostgreSQL database name"
}

# Do not output sensitive values like passwords or keys
