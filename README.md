# SEPTA Station Finder API

This project is a FastAPI-based API that finds the nearest SEPTA Regional Rail train station to a given location. It provides station information in GeoJSON format with walking directions, and implements modern application patterns for performance, security, and scalability.

## Features

- **Geospatial Processing**: Find the nearest SEPTA station from coordinates or text address
- **GeoJSON Output**: Standardized geographic data format for easy integration
- **Walking Directions**: Step-by-step directions to the nearest station via OSRM
- **JWT Authentication**: Secure user registration and API access
- **Redis Caching**: Response caching for improved performance
- **Rate Limiting**: SlowAPI-based rate limiting to prevent API abuse
- **Containerization**: Docker-based deployment with multi-stage builds
- **Database Migrations**: Alembic migrations for PostgreSQL
- **Async Architecture**: Non-blocking I/O for high concurrency

## Technology Stack

- **Python 3.12**: Modern Python version with latest features
- **FastAPI**: High-performance async web framework
- **SQLModel**: SQL databases in Python with type annotations
- **Redis**: In-memory data structure store for caching
- **PostgreSQL**: Relational database for persistent storage
- **GeoPandas**: Geospatial operations in Python
- **scikit-learn**: BallTree for efficient nearest-neighbor search
- **Docker**: Containerization for consistent deployment
- **UV**: Modern Python package manager and installer



## Project Structure

```
├── app/
│   ├── api/
│   │   ├── dependencies.py    # Dependency injection
│   │   ├── exceptions.py      # Custom exceptions
│   │   ├── routers/           # API endpoint routers
│   │   ├── security.py        # Authentication utilities
│   │   └── utils.py           # Geospatial utilities
│   ├── core/
│   │   ├── config.py          # Application configuration
│   │   └── settings.py        # Environment settings
│   ├── migrations/            # Alembic database migrations
│   └── models/                # SQLModel data models
├── data/                      # Static geospatial data
├── .env                       # Environment variables
├── alembic.ini                # Alembic configuration
├── Dockerfile                 # Multi-stage Docker build
├── docker-compose.yml         # Service orchestration
├── entrypoint.sh              # Container startup script
└── pyproject.toml            # Python project metadata
```
## Prerequisites

- Git
- Python 3.12
- UV package manager
- Docker & Docker Compose & Docker Desktop
- Terraform CLI

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/deancochran/septa-station-finder.git &&
   cd septa-station-finder
   ```

> If you prefer to download the repository as a zip file, you can do so from the
GitHub repository page. Unzip the folder in the directory of your choice and
navigate to the root directory.

## Environment Variables Configuration

The application requires a `.env` file for configuration. This file contains all the necessary environment variables for the application to run, including database credentials, security settings, and Docker configuration. You can set up this file for either local development or cloud deployment.

### A: For Local Deployment

For local development and testing, follow these steps to configure your environment:

#### Create the Environment File

Copy the provided `example.env` file and update the values as needed:

```bash
cp example.env .env
```

#### Configure Required Settings

Edit the `.env` file with your preferred text editor and update the following sections with appropriate values:

**Application Settings**
```
ENVIRONMENT=development    # Set to 'production' for production deployments
DEBUG=true                  # Set to 'false' in production
LOG_LEVEL=DEBUG             # Options: DEBUG, INFO, WARNING, ERROR, CRITICAL
```

**Security**

Generate a SECRET_KEY with the terminal command:
```bash
openssl rand -hex 32
```
```
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256              # JWT signing algorithm
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

**Database Configuration**

Ensure that you update the DATABASE_URL manually to match your PostgreSQL setup

ie: if POSTGRES_DB=septadb and the url unupdated url contains "...../{POSTGRES_DB}" the end result should be "...../septadb
```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=septadb
# This URL must be updated with the correct database variables
DATABASE_URL=postgresql+asyncpg://{POSTGRES_USER}:{POSTGRES_PASSWORD}@postgres:5432/{POSTGRES_DB}
```

**Redis Configuration**

Ensure that you update the REDIS_URL manually to match your REDIS setup

ie: if REDIS_PASSWORD=your_redis_password and the url unupdated url contains "redis://:{REDIS_PASSWORD}@redis:6379/0" the end result should be "redis://:your_redis_password@redis:6379/0"
```
REDIS_PASSWORD=your_redis_password
# This URL must be updated with the correct database variables
REDIS_URL=redis://:{REDIS_PASSWORD}@redis:6379/0
```

**Docker Configuration**
```
COMPOSE_BAKE=true
DOCKER_BUILDKIT=1
WATCHFILES_FORCE_POLLING=true
DEBUG=1
```

### B: For Cloud Deployment

For cloud deployments, Terraform provides an automated way to generate the `.env` file with secure random passwords and keys. This approach is recommended for production environments.

#### Configure Terraform Variables

Navigate to the Terraform directory and copy the example variables file:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

#### Edit the Variables File

Open the `terraform.tfvars` file and set your desired configuration values. The file contains settings for:

- AWS region and deployment options
- Application environment (development, production, staging, test)
- Database and Redis configuration
- Security settings
- Docker credentials
- Auto-scaling parameters

Example:
```
# AWS Configuration
aws_region = "us-east-1"
aws_deploy = true  # Set to true to deploy to AWS

# Application Settings
environment = "production"
debug = false
log_level = "INFO"

# Database Configuration
postgres_user = "gisual"
use_generated_db_password = true
```

**NOTE: after Initialization and Application of the Terraform configuration, this will:**
- Generate a properly configured `.env` file at the project root
- Create secure random passwords if enabled in your configuration
- Set up the necessary AWS infrastructure if `aws_deploy` is set to `true`


## How to Deploy the App

There are two main deployment options, locally and using the cloud. This can only be done once the proper environment variables have been collected to form a `.env` file

### A: For Local Deployment

Ensure that the Docker Daemon is running and is accessible. (Or use ensure that Docker Desktop is running and is accessible.)

**Note: Locally the application uses 3 different ports: (please ensure none of the following are in use prior to deploying locally) port 8000 (fastapi), 5432 (postgres), and 6379 (redis)**

```bash

# Start the application
docker-compose up -d

# view logs
docker-compose logs -f

# restart the application
docker-compose restart

# stop the application
docker-compose down

# Apply migrations to head
docker compose exec api alembic upgrade head

# Revert migrations from current
docker compose exec api alembic downgrade -1

# Upgrade migrations from current
docker compose exec api alembic upgrade +1`
```

## B: For Cloud Deployment

This approach uses AWS Elastic Container Service with Fargate for serverless container management:

1. **Build and push the Docker image**:
   ```bash
   # Build the image
   docker build -t septa-api .

   # Tag with ECR repository URL
   docker tag septa-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/septa-api:latest

   # Log in to ECR
   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

   # Push to ECR
   docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/septa-api:latest
   ```

2. **Set up AWS Infrastructure**:
   ```bash
   # Navigate to Terraform directory
   cd terraform

   # Apply Terraform configuration
   terraform apply
   ```

3. **Update service**:
   ```bash
   aws ecs update-service --cluster septa-api-cluster --service septa-api-service --force-new-deployment
   ```

4. **Access your API** at the ALB DNS name provided in the Terraform outputs

### Database Migration in AWS

To run database migrations after deployment:

```bash
# For ECS
aws ecs run-task \
  --cluster septa-api-cluster \
  --task-definition septa-api-migration \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --launch-type FARGATE
```


## How to Use




## Development


1. Install UV:
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
2. Create and activate a virtual environment using UV:
   ```bash
   uv venv &&
   source .venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   uv add -r requirements.txt
   ```

4. Edit the App!
