# SEPTA Station Finder API

This project is a FastAPI-based API that finds the nearest SEPTA Regional Rail train station to a given location. It provides station information in GeoJSON format with walking directions, and implements modern application patterns for performance, security, and scalability.

## Features

- **Geospatial Processing**: Find the nearest SEPTA station from coordinates or text address
- **GeoJSON Output**: Standardized geographic data format for easy integration
- **Walking Directions**: Step-by-step directions to the nearest station via OSRM
- **JWT Authentication**: Secure user registration and API access
- **Redis Caching**: Response caching for improved performance
- **Containerization**: Docker-based deployment with multi-stage builds
- **Database Migrations**: Alembic migrations for PostgreSQL
- **Async Architecture**: Non-blocking I/O for high concurrency

## Project Approach and Design Decisions

### Approach

This project was developed with a focus on creating a highly scalable and maintainable API for geospatial data processing. The development approach followed these principles:

1. **API-First Design**: The API endpoints were designed before implementation, with careful consideration for user experience and data format standardization.

2. **Domain-Driven Design**: The codebase is organized around business domains rather than technical concerns, making it easier to understand and extend.

3. **Progressive Enhancement**: Core functionality was implemented first, followed by optimizations like caching and performance improvements.

4. **Containerization from Day One**: Docker was used from the beginning to ensure consistent development and deployment environments.

### Technical Decisions

#### FastAPI + Async

I chose FastAPI for its combination of performance, type safety, and developer experience:

- **Async Support**: Leveraging Python's async/await syntax for high-concurrency operations, especially important for geospatial calculations and database queries
- **Type Annotations**: Using Python's type system for self-documenting code and early error detection
- **Automatic Documentation**: OpenAPI documentation generated automatically from code

#### SQLModel

SQLModel was selected over other ORMs for its seamless integration with both Pydantic and SQLAlchemy:

- **Type Safety**: Full type hints for database models
- **Single Model Definition**: Combining API models and database models into a single definition
- **Async Support**: Built-in support for asynchronous database operations

#### Geospatial Processing Strategy

The geospatial nearest-neighbor search is implemented using a BallTree data structure from scikit-learn with these considerations:

- **Haversine Distance**: Using the correct spherical distance metric for geographic coordinates
- **Pre-computation**: Building the BallTree once at startup for efficient queries
- **KNN Queries**: Finding k-nearest neighbors efficiently without scanning all possible points

#### Caching Architecture

The caching strategy was designed to balance performance and data freshness:

- **Coordinate-Based Keys**: Cache keys based on latitude/longitude to ensure identical requests get cached results
- **Redis as Primary Cache**: Using Redis for its performance, persistence options, and distributed capabilities
- **Non-Blocking Implementation**: Async Redis client to prevent blocking the event loop

### Challenges and Solutions

#### Challenge 1: Efficient Geospatial Queries

**Problem**: Finding the nearest station efficiently from a geospatial dataset.

**Solution**: Implemented a scikit-learn BallTree with haversine distance metric, which provides O(log n) query time instead of O(n) for linear search. This approach is particularly efficient for static datasets like train stations.

#### Challenge 2: Docker Build Optimization

**Problem**: Long build times and large Docker images slowing down the development cycle.

**Solution**: Implemented a multi-stage Docker build process that:
- Uses a builder stage for compiling dependencies with proper build tools
- Creates a lean runtime image with only necessary components
- Leverages Docker BuildKit for parallel dependency resolution

#### Challenge 3: Asynchronous Database Access

**Problem**: Ensuring database access doesn't block the API server when under load.

**Solution**: Implemented fully asynchronous database access with proper connection pooling and transaction management, allowing the server to handle many concurrent requests without degrading performance.

#### Challenge 4: Walking Directions Integration

**Problem**: Providing accurate walking directions to stations without implementing a complete routing engine.

**Solution**: Integrated with OSRM (OpenStreetMap Routing Machine) for walking directions, using a resilient HTTP client with proper error handling and timeout configuration.

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

## Prerequisites

- Python 3.12
- UV package manager
- Docker & Docker Compose
- A machine with adequate memory for geospatial operations

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/septa-station-finder.git
   cd septa-station-finder
   ```

2. Create and activate a virtual environment using UV:
   ```bash
   # Install UV
   curl -LsSf https://astral.sh/uv/install.sh | sh

   # Create virtual environment
   uv venv
   source .venv/bin/activate  # On Unix/macOS
   ```

3. Install dependencies:
   ```bash
   uv pip install -e .
   ```

## Environment Variables Configuration

The application uses a `.env` file for configuration. You can set up this file in two ways:

### Manual Setup

Copy the provided `example.env` file and update the values as needed:

```bash
cp example.env .env
```

Then edit the `.env` file to configure the following sections:

### Automated Setup with Terraform

For a more automated approach, you can use the provided Terraform configuration:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars  # Edit this file with your settings
terraform init
terraform apply
```

This will generate a properly configured `.env` file with secure random passwords and keys. See the `terraform/README.md` file for more details.

### Configuration Sections

### Application Settings

```
ENVIRONMENT=development    # Set to 'production' for production deployments
DEBUG=true                  # Set to 'false' in production
LOG_LEVEL=DEBUG             # Options: DEBUG, INFO, WARNING, ERROR, CRITICAL
```

### Security

```
# Generate a SECRET_KEY with the terminal command: openssl rand -hex 32
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256              # JWT signing algorithm
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### Database Configuration

```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=septadb
# This URL must match the above settings
DATABASE_URL=postgresql+asyncpg://postgres:your_postgres_password@postgres:5432/septadb
```

### Redis Configuration

```
REDIS_PASSWORD=your_redis_password
# This URL must include the password set above
REDIS_URL=redis://:your_redis_password@redis:6379/0
```

### Docker Configuration

```
DOCKER_USERNAME=your_docker_username    # Your Docker Hub username
DOCKER_PASSWORD=your_docker_password    # Your Docker Hub password
COMPOSE_BAKE=true
DOCKER_BUILDKIT=1
WATCHFILES_FORCE_POLLING=true
DEBUG=1
```

## Running the Application

### Using Docker (Recommended)

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Local Development

1. Ensure Redis and PostgreSQL are running
2. Start the FastAPI application:
   ```bash
   fastapi run app/api/main.py --reload
   ```

3. Access the API documentation at http://localhost:8000/docs

## AWS Cloud Deployment

The application can be deployed to AWS using various services. Here is a comprehensive guide for deployment:

### Prerequisites

- AWS Account
- AWS CLI configured with appropriate permissions
- Terraform installed (for automated deployment)

### Deployment Options

#### Option 1: AWS ECS Fargate (Container-based)

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
   
   # Initialize Terraform
   terraform init
   
   # Apply Terraform configuration
   terraform apply
   ```

3. **Update service**:
   ```bash
   aws ecs update-service --cluster septa-api-cluster --service septa-api-service --force-new-deployment
   ```

4. **Access your API** at the ALB DNS name provided in the Terraform outputs

#### Option 2: AWS Elastic Beanstalk (Simpler Deployment)

For a more managed approach with less configuration:

1. **Install the EB CLI**:
   ```bash
   pip install awsebcli
   ```

2. **Initialize EB**:
   ```bash
   eb init -p docker septa-api
   ```

3. **Create environment and deploy**:
   ```bash
   eb create septa-api-production
   ```

4. **For future deployments**:
   ```bash
   eb deploy
   ```

### AWS Infrastructure Requirements

The application requires the following AWS resources:

- **Networking**: VPC, subnets, security groups
- **Compute**: ECS Cluster with Fargate or Elastic Beanstalk
- **Database**: Amazon RDS for PostgreSQL
- **Caching**: Amazon ElastiCache for Redis
- **Storage**: S3 bucket for static data
- **Security**: IAM roles with appropriate permissions

### Database Migration in AWS

To run database migrations after deployment:

```bash
# For ECS
aws ecs run-task \
  --cluster septa-api-cluster \
  --task-definition septa-api-migration \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --launch-type FARGATE

# For Elastic Beanstalk
eb ssh
cd /var/app/current
alembic upgrade head
```

### Automated Deployment with GitHub Actions

The repository includes GitHub Actions workflows for CI/CD to AWS:

```yaml
# Example AWS deployment workflow steps
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: septa-api
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
      - name: Deploy to ECS
        run: |
          aws ecs update-service --cluster septa-api-cluster --service septa-api-service --force-new-deployment
```

### Cost Optimization

To optimize costs for AWS deployment:

- Use Fargate Spot for non-critical workloads
- Set up auto-scaling based on demand
- Use the AWS Free Tier when available
- Consider using reserved instances for Redis and RDS
- Implement lifecycle policies for ECR images

## API Endpoints

### Authentication

- **POST /auth/register** - Create new user account
  ```json
  {
    "username": "example_user",
    "email": "user@example.com",
    "password": "SecurePass123"
  }
  ```

- **POST /auth/login** - Authenticate and get JWT token
  ```json
  {
    "username": "example_user",
    "password": "SecurePass123"
  }
  ```

### SEPTA Station API

- **POST /septa/find-nearest-station** - Find nearest station
  ```json
  {
    "address": "30th Street Station, Philadelphia, PA"
    // OR use coordinates
    "latitude": 39.9566,
    "longitude": -75.1819
  }
  ```

  Response includes:
  - Station name and distance
  - GeoJSON formatted station data
  - Walking directions with distance and duration

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

## Database Migrations

The application uses Alembic for database migrations:

```bash
# Generate a new migration
alembic revision --autogenerate -m "Description"

# Apply migrations
alembic upgrade head
```

## Geospatial Processing

The application uses:
- **BallTree** from scikit-learn for efficient nearest-neighbor search
- **Haversine distance** metric for accurate Earth-surface calculations
- **GeoPandas** for spatial data structures
- **OpenStreetMap Routing Machine** (OSRM) for walking directions

## Caching Strategy

Redis is used for caching with these features:
- Location-based cache keys
- Request deduplication
- Non-blocking async access
- Configurable connection timeout

## GitHub Actions Workflow

The repository includes a GitHub Actions workflow for building and pushing Docker images:

```yaml
# .github/workflows/docker-build-push.yml
name: Docker Build and Push

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-push:
    # Configuration for building and pushing Docker images
```

## Security Considerations

- **Passwords**: Securely hashed with bcrypt
- **API Access**: Secured with JWT tokens
- **Rate Limiting**: Prevent abuse (implemented via Redis)
- **Environment Variables**: Separation of configuration and code
