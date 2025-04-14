# AWS Configuration for SEPTA Station Finder API

# This file contains AWS resources that will only be created
# when var.aws_deploy is set to true

# ECR Repository for Docker images
resource "aws_ecr_repository" "septa_api" {
  count = var.aws_deploy ? 1 : 0
  name  = "septa-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "septa-api"
    Environment = var.environment
  }
}

# VPC for the application
resource "aws_vpc" "main" {
  count = var.aws_deploy ? 1 : 0
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "septa-api-vpc"
    Environment = var.environment
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = var.aws_deploy ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true

  tags = {
    Name        = "septa-api-public-${count.index}"
    Environment = var.environment
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = var.aws_deploy ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "septa-api-private-${count.index}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  count = var.aws_deploy ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name        = "septa-api-igw"
    Environment = var.environment
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  count = var.aws_deploy ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw[0].id
  }

  tags = {
    Name        = "septa-api-public-rt"
    Environment = var.environment
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "public" {
  count = var.aws_deploy ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Security group for the API
resource "aws_security_group" "api" {
  count = var.aws_deploy ? 1 : 0
  name        = "septa-api-sg"
  description = "Security group for SEPTA API"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "septa-api-sg"
    Environment = var.environment
  }
}

# Security group for RDS
resource "aws_security_group" "postgres" {
  count = var.aws_deploy ? 1 : 0
  name        = "septa-postgres-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "septa-postgres-sg"
    Environment = var.environment
  }
}

# Security group for Redis
resource "aws_security_group" "redis" {
  count = var.aws_deploy ? 1 : 0
  name        = "septa-redis-sg"
  description = "Security group for Redis ElastiCache"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "septa-redis-sg"
    Environment = var.environment
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "postgres" {
  count = var.aws_deploy ? 1 : 0
  name        = "septa-postgres-subnet-group"
  description = "Subnet group for SEPTA PostgreSQL RDS"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name        = "septa-postgres-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis" {
  count = var.aws_deploy ? 1 : 0
  name        = "septa-redis-subnet-group"
  description = "Subnet group for SEPTA Redis ElastiCache"
  subnet_ids  = aws_subnet.private[*].id
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  count = var.aws_deploy ? 1 : 0
  identifier             = "septa-postgres"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.postgres_db
  username               = var.postgres_user
  password               = var.use_generated_db_password ? random_password.postgres_password.result : var.postgres_password
  db_subnet_group_name   = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids = [aws_security_group.postgres[0].id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name        = "septa-postgres"
    Environment = var.environment
  }
}

# ElastiCache Redis cluster
resource "aws_elasticache_cluster" "redis" {
  count = var.aws_deploy ? 1 : 0
  cluster_id           = "septa-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis[0].name
  security_group_ids   = [aws_security_group.redis[0].id]

  tags = {
    Name        = "septa-redis"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "api" {
  count = var.aws_deploy ? 1 : 0
  name               = "septa-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api[0].id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "septa-api-alb"
    Environment = var.environment
  }
}

# ALB target group
resource "aws_lb_target_group" "api" {
  count = var.aws_deploy ? 1 : 0
  name     = "septa-api-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main[0].id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name        = "septa-api-tg"
    Environment = var.environment
  }
}

# ALB listener
resource "aws_lb_listener" "api" {
  count = var.aws_deploy ? 1 : 0
  load_balancer_arn = aws_lb.api[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }

  tags = {
    Name        = "septa-api-listener"
    Environment = var.environment
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "api" {
  count = var.aws_deploy ? 1 : 0
  name = "septa-api-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "septa-api-cluster"
    Environment = var.environment
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  count = var.aws_deploy ? 1 : 0
  name = "septa-api-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "septa-api-task-execution-role"
    Environment = var.environment
  }
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count = var.aws_deploy ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "api" {
  count = var.aws_deploy ? 1 : 0
  family                   = "septa-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "septa-api"
      image     = "${aws_ecr_repository.septa_api[0].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DEBUG", value = var.debug ? "true" : "false" },
        { name = "LOG_LEVEL", value = var.log_level },
        { name = "ALGORITHM", value = var.algorithm },
        { name = "ACCESS_TOKEN_EXPIRE_MINUTES", value = tostring(var.token_expire_mins) },
        { name = "POSTGRES_USER", value = var.postgres_user },
        { name = "POSTGRES_DB", value = var.postgres_db },
        { name = "POSTGRES_HOST", value = aws_db_instance.postgres[0].address },
        { name = "POSTGRES_PORT", value = tostring(aws_db_instance.postgres[0].port) },
        { name = "REDIS_HOST", value = aws_elasticache_cluster.redis[0].cache_nodes[0].address },
        { name = "REDIS_PORT", value = tostring(aws_elasticache_cluster.redis[0].cache_nodes[0].port) },
        { name = "DOCKER_BUILDKIT", value = tostring(var.docker_buildkit) },
        { name = "WATCHFILES_FORCE_POLLING", value = var.watchfiles_polling ? "true" : "false" }
      ]
      secrets = [
        { name = "SECRET_KEY", valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current[0].account_id}:parameter/septa-api/secret-key" },
        { name = "POSTGRES_PASSWORD", valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current[0].account_id}:parameter/septa-api/postgres-password" },
        { name = "REDIS_PASSWORD", valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current[0].account_id}:parameter/septa-api/redis-password" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/septa-api"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "septa-api-task"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "api" {
  count = var.aws_deploy ? 1 : 0
  name            = "septa-api-service"
  cluster         = aws_ecs_cluster.api[0].id
  task_definition = aws_ecs_task_definition.api[0].arn
  desired_count   = var.min_capacity
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 60
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.api[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api[0].arn
    container_name   = "septa-api"
    container_port   = 8000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.api[0]
  ]

  lifecycle {
    ignore_changes = [desired_count] # Allow autoscaling to manage this
  }

  tags = {
    Name        = "septa-api-service"
    Environment = var.environment
  }
}

# ECS Auto Scaling
resource "aws_appautoscaling_target" "api" {
  count = var.aws_deploy ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.api[0].name}/${aws_ecs_service.api[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU Utilization Scaling Policy
resource "aws_appautoscaling_policy" "cpu" {
  count = var.aws_deploy ? 1 : 0
  name               = "septa-api-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Memory Utilization Scaling Policy
resource "aws_appautoscaling_policy" "memory" {
  count = var.aws_deploy ? 1 : 0
  name               = "septa-api-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Request Count Scaling Policy
resource "aws_appautoscaling_policy" "requests" {
  count = var.aws_deploy ? 1 : 0
  name               = "septa-api-request-count-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.api[0].arn_suffix}/${aws_lb_target_group.api[0].arn_suffix}"
    }
    target_value       = var.requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {
  count = var.aws_deploy ? 1 : 0
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api" {
  count = var.aws_deploy ? 1 : 0
  name = "/ecs/septa-api"
  retention_in_days = 30

  tags = {
    Name        = "septa-api-logs"
    Environment = var.environment
  }
}

# SSM Parameters for secrets
resource "aws_ssm_parameter" "secret_key" {
  count = var.aws_deploy ? 1 : 0
  name  = "/septa-api/secret-key"
  type  = "SecureString"
  value = var.use_generated_secret ? random_id.secret_key.hex : var.secret_key

  tags = {
    Name        = "septa-api-secret-key"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "postgres_password" {
  count = var.aws_deploy ? 1 : 0
  name  = "/septa-api/postgres-password"
  type  = "SecureString"
  value = var.use_generated_db_password ? random_password.postgres_password.result : var.postgres_password

  tags = {
    Name        = "septa-api-postgres-password"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "redis_password" {
  count = var.aws_deploy ? 1 : 0
  name  = "/septa-api/redis-password"
  type  = "SecureString"
  value = var.use_generated_redis_password ? random_password.redis_password.result : var.redis_password

  tags = {
    Name        = "septa-api-redis-password"
    Environment = var.environment
  }
}

# Outputs for AWS deployment
output "aws_alb_dns" {
  value       = var.aws_deploy ? aws_lb.api[0].dns_name : null
  description = "DNS name of the Application Load Balancer"
}

output "aws_ecr_repository_url" {
  value       = var.aws_deploy ? aws_ecr_repository.septa_api[0].repository_url : null
  description = "URL of the ECR repository"
}

output "aws_rds_endpoint" {
  value       = var.aws_deploy ? aws_db_instance.postgres[0].endpoint : null
  description = "Endpoint of the RDS instance"
}

output "aws_redis_endpoint" {
  value       = var.aws_deploy ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : null
  description = "Endpoint of the ElastiCache Redis cluster"
}