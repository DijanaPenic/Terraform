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

variable "image_name" {
  description = "image name"
  type = string
}