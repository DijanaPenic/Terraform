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

variable "app_name" {
  description = "application name"
  type = string
}

variable "image_name" {
  description = "image name"
  type = string
}

variable "ssh_key_private" {
  description = "ssh private key path"
  type = string
}

variable "ssh_key_public" {
  description = "ssh public key path"
  type = string
}

variable "ansible_path" {
  description = "ansible directory path"
  type = string
}