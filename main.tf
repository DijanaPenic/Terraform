terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "app-name"

    workspaces {
      name = "test-workspace"
    }
  }

  required_version = ">= 1.1.0"
}

provider "aws" { 
  region = var.region
}

# Create VPC
resource "aws_vpc" "myapp-vpc" {
  cidr_block  = var.vpc-cidr

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-vpc"
  }
}

# Create private subnets
resource "aws_subnet" "myapp-private-subnets" {
  vpc_id            = aws_vpc.myapp-vpc.id
  count             = length(var.azs)
  cidr_block        = element(var.private-subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-private-subnet-${count.index+1}"
  }
}

# Create public subnets
resource "aws_subnet" "myapp-public-subnets" {
  vpc_id            = aws_vpc.myapp-vpc.id
  count             = length(var.azs)
  cidr_block        = element(var.public-subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-public-subnet-${count.index+1}"
  }
}

# Set locals
locals {
  public_subnets = [for subnet in aws_subnet.myapp-public-subnets : subnet.id]
  private_subnets = [for subnet in aws_subnet.myapp-private-subnets : subnet.id]
}

# Create IGW
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-igw"
  }
}

# Single route table for public subnet
resource "aws_route_table" "myapp-public-rtable" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-public-rtable"
  }
}

# Add routes to public-rtable
resource "aws_route" "myapp-public-rtable" {
  route_table_id         = aws_route_table.myapp-public-rtable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.myapp-igw.id
}

# Route table association public subnets
resource "aws_route_table_association" "myapp-public-subnet-association" {
  count          = length(var.public-subnets)
  subnet_id      = element(aws_subnet.myapp-public-subnets.*.id, count.index)
  route_table_id = aws_route_table.myapp-public-rtable.id
}

# Private route tables
resource "aws_route_table" "myapp-private-rtable" {
  count  = length(var.private-subnets)
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-private-rtable-${count.index+1}"
  }
}

# Route table association private subnets
resource "aws_route_table_association" "myapp-private-subnet-association" {
  count          = length(var.private-subnets)
  subnet_id      = element(aws_subnet.myapp-private-subnets.*.id, count.index)
  route_table_id = element(aws_route_table.myapp-private-rtable.*.id, count.index)
}

# EIP
resource "aws_eip" "myapp-nat-eip" {
  count = length(var.azs)
  vpc   = true

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-eip-${count.index+1}"
  }
}

# NAT gateways
resource "aws_nat_gateway" "myapp-nat-gateway" {
  count         = length(var.azs)
  allocation_id = element(aws_eip.myapp-nat-eip.*.id, count.index)
  subnet_id     = element(aws_subnet.myapp-public-subnets.*.id, count.index)

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-natgw--${count.index+1}"
  }
}

# Add routes to private-rtable
resource "aws_route" "myapp-subnets-private-rtable" {
  count                  = length(var.azs)
  route_table_id         = element(aws_route_table.myapp-private-rtable.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.myapp-nat-gateway.*.id, count.index)
}

# Security group for ECS service
resource "aws_security_group" "myapp-service-sg" {
  name        = "${var.app_name}-${var.env_prefix}-service-sg"
  description = "ECS service sg"
  vpc_id      = aws_vpc.myapp-vpc.id

  ingress {
    description = "Enable LB traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups = [aws_security_group.myapp-lb-sg.id]
  }

  egress { 
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-service-sg"
  }
}

# Security group for load balancer
resource "aws_security_group" "myapp-lb-sg" {
  name        = "${var.app_name}-${var.env_prefix}-lb-sg"
  description = "ECS lb sg"
  vpc_id      = aws_vpc.myapp-vpc.id

  ingress { 
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { 
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-lb-sg"
  }
}

# Create ECS cluster
resource "aws_ecs_cluster" "myapp-cluster-ecs" {
  name = "${var.app_name}-${var.env_prefix}-cluster-ecs"
}

resource "aws_ecs_cluster_capacity_providers" "myapp-cluster-providers" {
  cluster_name       = aws_ecs_cluster.myapp-cluster-ecs.name
  capacity_providers = ["FARGATE"]
}

# Create ECS execution role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Create ECR for build images
resource "aws_ecr_repository" "myapp-ecr" {
  name                 = "${var.app_name}-${var.env_prefix}-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS task definition
resource "aws_ecs_task_definition" "myapp-ecs-task" {
  family                   = "${var.app_name}-${var.env_prefix}-ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = "${data.aws_iam_role.ecs_task_execution_role.arn}"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "PostgresDB",
      "image": "postgres:latest",
      "healthCheck": {
        "retries": 5,
        "command": [
          "CMD-SHELL",
          "pg_isready -U postgres"
        ],
        "timeout": 5,
        "interval": 5,
        "startPeriod": 1
      },
      "portMappings": [
        {
          "hostPort": 5432,
          "protocol": "tcp",
          "containerPort": 5432
        }
      ],
      "environment": [
        {
          "name": "POSTGRES_USER",
          "value": "${var.db_username}"
        },
        {
          "name": "POSTGRES_DB",
          "value": "${var.db_name}"
        },
        {
          "name": "POSTGRES_PASSWORD",
          "value": "${var.db_password}"
        }
      ]
    },
    {
      "name": "WebAPI",
      "image": "${aws_ecr_repository.myapp-ecr.repository_url}:latest",
      "portMappings": [
        {
          "hostPort": 443,
          "protocol": "tcp",
          "containerPort": 443
        }
      ],
      "dependsOn": [
        {
          "containerName": "PostgresDB",
          "condition": "HEALTHY"
        }
      ],
      "environment": [
        {
          "name": "ASPNETCORE_ENVIRONMENT",
          "value": "Development"
        },
        {
          "name": "ASPNETCORE_URLS",
          "value": "http://+:443"
        },
        {
          "name": "${var.app_name}APP_POSTGRES__CONNECTIONSTRING",
          "value": "server=localhost;userid=${var.db_username};password=${var.db_password};port=5432;database=${var.db_name};application name=${var.app_name};"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/${var.app_name}-${var.env_prefix}-ecs-task",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  TASK_DEFINITION
}

# Load balancer
resource "aws_lb_target_group" "myapp-target-group" {
  name        = "${var.app_name}-${var.env_prefix}-target-group"
  port        = 443
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.myapp-vpc.id
}

resource "aws_lb" "myapp-lb" {
  name               = "${var.app_name}-${var.env_prefix}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.myapp-lb-sg.id]
  subnets            = local.public_subnets
  enable_deletion_protection = false
}

resource "aws_lb_listener" "myapp-lb-listener" {
  load_balancer_arn = aws_lb.myapp-lb.arn
  port              = "5000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myapp-target-group.arn
  }
}

# ECS service
resource "aws_ecs_service" "myapp-ecs-service" {
  name            = "${var.app_name}-${var.env_prefix}-ecs-service"
  cluster         = aws_ecs_cluster.myapp-cluster-ecs.id
  task_definition = aws_ecs_task_definition.myapp-ecs-task.arn
  desired_count   = 2
  launch_type     = "FARGATE" 

  network_configuration {
    subnets          = local.public_subnets
    security_groups  = [aws_security_group.myapp-service-sg.id]
    assign_public_ip = true
  }

  # Multiple load_balancer blocks are supported.
  load_balancer {
    target_group_arn = aws_lb_target_group.myapp-target-group.arn
    container_name   = "WebAPI"
    container_port   = 443
  }
}

# Build role
resource "aws_iam_role" "myapp-build-role" {
  name = "${var.app_name}-${var.env_prefix}-build-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

// TODO - check subnets.
resource "aws_iam_role_policy" "myapp-build-policy" {
  role   = aws_iam_role.myapp-build-role.name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:Subnet": [ 
            "${aws_subnet.myapp-public-subnets[0].arn}",
            "${aws_subnet.myapp-public-subnets[1].arn}"
          ],
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_codebuild_source_credential" "github-credentials" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

# Build project
resource "aws_codebuild_project" "myapp-build-project" {
  name          = "${var.app_name}-${var.env_prefix}-build-project"
  build_timeout = "5"
  service_role  = aws_iam_role.myapp-build-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "284961654400"
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.myapp-ecr.name
    }
    environment_variable {
      name  = "BUILD_CONFIGURATION"
      value = var.build_config
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_project_url
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "ecs"

  vpc_config {
    vpc_id             = aws_vpc.myapp-vpc.id
    subnets            = local.private_subnets
    security_group_ids = [aws_vpc.myapp-vpc.default_security_group_id]
  }
}