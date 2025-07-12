output "medusa_url" {
  value       = "http://${aws_ecs_service.service.load_balancer_dns_name}:9000"
  description = "URL to access Medusa (if using load balancer)"
}

output "database_endpoint" {
  value       = aws_db_instance.medusa_db.endpoint
  description = "PostgreSQL connection endpoint"
  sensitive   = true
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECR repository URL for Medusa images"
}