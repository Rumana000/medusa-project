variable "aws_region" {
  default = "us-east-1"
}

variable "image_uri" {}

variable "db_name" {
  default = "medusa"
}

variable "db_user" {
  default = "medusa_admin"
}

variable "db_password" {
  sensitive = true
}