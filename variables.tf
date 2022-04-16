variable "env_prefix" {
  description = "deployment environment"
  default = "test"
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