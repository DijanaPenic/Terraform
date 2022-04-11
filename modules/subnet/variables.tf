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

variable "vpc_id" {
  description = "VPC id"
  type = string
}

variable "default_route_table_id" {
  description = "Default route table id"
  type = string
}

variable "app_name" {
  description = "application name"
  type = string
}