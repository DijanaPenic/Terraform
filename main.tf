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
  cidr_block = var.vpc_cider_block
  enable_dns_hostnames = true
  tags = {
    Name: "${var.app_name}-${var.env_prefix}-vpc"
  }
}

module "myapp-subnet" {
  source = "./modules/subnet"
  subnet_cider_block = var.subnet_cider_block
  availability_zone = var.availability_zone
  env_prefix = var.env_prefix
  vpc_id = aws_vpc.myapp-vpc.id
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  app_name = var.app_name
}

module "myapp-server" {
  source = "./modules/webserver"
  vpc_id = aws_vpc.myapp-vpc.id
  my_ip = var.my_ip
  env_prefix = var.env_prefix
  image_name = var.image_name
  instance_type = var.instance_type
  subnet_id = module.myapp-subnet.subnet.id
  availability_zone = var.availability_zone
  app_name = var.app_name
  ssh_key_private = var.ssh_key_private
  ssh_key_public = var.ssh_key_public
  ansible_path = var.ansible_path
}