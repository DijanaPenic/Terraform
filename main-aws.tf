terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "robot-cleaner"

    workspaces {
      name = "test-workspace"
    }
  }

  required_version = ">= 1.1.0"
}

variable "vpc_cider_block" {
  description = "VPC cider block"
  type = string
}

variable "subnet_cider_block" {
  description = "subnet cider block"
  type = string
}

variable "availability_zone" {
  description = "availability zone"
  type = string
}

variable "env_prefix" {
  description = "deployment environment"
  default = "test"
  type = string
}

variable "my_ip" {
  description = "my IP address"
  type = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type = string
}

# variable "public_key_location" {
#   description = "SSH public key location"
#   type = string
# }

variable "app_name" {
  description = "application name"
  type = string
}

provider "aws" { }

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cider_block
  tags = {
    Name: "${var.app_name}-${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cider_block
  availability_zone = var.availability_zone
  tags = {
      Name: "${var.app_name}-${var.env_prefix}-subnet-1"
  }
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

resource "aws_default_security_group" "myapp-main-sg" {
  vpc_id = aws_vpc.myapp-vpc.id
  ingress { 
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }
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
    "Name" = "${var.app_name}-${var.env_prefix}-main-sg"
  }
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file("id_rsa.pub")
}

resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.myapp-main-sg.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    "Name" = "${var.app_name}-${var.env_prefix}-server"
  }
}