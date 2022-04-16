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
  region = "eu-central-1"
}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name: "${var.app_name}-${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-central-1a"
  tags = {
      Name: "${var.app_name}-${var.env_prefix}-subnet-1"
  }
}

resource "aws_subnet" "myapp-subnet-2" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1b"
  tags = {
      Name: "${var.app_name}-${var.env_prefix}-subnet-2"
  }
}

locals {
  subnets = [aws_subnet.myapp-subnet-1.id, aws_subnet.myapp-subnet-2.id]
}

resource "aws_route_table_association" "myapp-subnets-rt" {
  count          = length(local.subnets)
  subnet_id      = local.subnets[count.index]
  route_table_id = aws_default_route_table.myapp-main-rtb.id
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    "Name" = "${var.app_name}-${var.env_prefix}-igw"
  }
}

resource "aws_default_route_table" "myapp-main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    "Name" = "${var.app_name}-${var.env_prefix}-main-rtb"
  }
}

resource "aws_security_group" "myapp-lb-sg" {
  name = "${var.app_name}-${var.env_prefix}-lb-sg"
  description = "ECS lb sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress { 
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-lb-sg"
  }
}

resource "aws_security_group" "myapp-service-sg" {
  name = "${var.app_name}-${var.env_prefix}-service-sg"
  description = "ECS service sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    description = "Enable LB traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups = [aws_security_group.myapp-lb-sg.id]
  }

  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.app_name}-${var.env_prefix}-service-sg"
  }
}

resource "aws_ecs_cluster" "myapp-cluster-ecs" {
  name = "${var.app_name}-${var.env_prefix}-cluster-ecs"
}

resource "aws_ecs_cluster_capacity_providers" "myapp-cluster-providers" {
  cluster_name = aws_ecs_cluster.myapp-cluster-ecs.name
  capacity_providers = ["FARGATE"]
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

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

  container_definitions    = <<TASK_DEFINITION
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
      "image": "284961654400.dkr.ecr.eu-central-1.amazonaws.com/misc:latest",
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
          "name": "ROBOTCLEANERAPP_POSTGRES__CONNECTIONSTRING",
          "value": "server=localhost;userid=postgres;password=${var.db_password};port=5432;database=${var.db_name};application name=${var.app_name};"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/app-name-test-ecs-task",
          "awslogs-region": "eu-central-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  TASK_DEFINITION
}

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
  subnets            = local.subnets
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

resource "aws_ecs_service" "myapp-ecs-service" {
  name            = "${var.app_name}-${var.env_prefix}-ecs-service"
  cluster         = aws_ecs_cluster.myapp-cluster-ecs.id
  task_definition = aws_ecs_task_definition.myapp-ecs-task.arn
  desired_count   = 2
  launch_type     = "FARGATE" 

  network_configuration {
    subnets          = local.subnets
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