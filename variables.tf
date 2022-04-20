variable "env_prefix" {
  description = "deployment environment"
  default = "test"
  type = string
}

variable "build_config" {
  description = "build configuration"
  default = "Debug"
  type = string
}

variable "app_name" {
  description = "application name"
  default = "app-name"
  type = string
}

variable "db_name" {
  description = "Database name"
  default = "AppName"
  type        = string
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}

# variable "github_token" {
#   description = "Github access token"
#   type        = string
#   sensitive   = true
# }

variable "github_project" {
  description = "Github project"
  type        = string
}

variable "github_branch" {
  description = "Github project branch"
  type        = string
}

variable "region" {
  default = "eu-central-1"
}

variable "vpc-cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "private-subnets" {
  type = list
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public-subnets" {
  type = list
  default = ["10.0.20.0/24", "10.0.21.0/24"]
}