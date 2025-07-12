variable "image_uri" {
  description = "ECR image URI"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}