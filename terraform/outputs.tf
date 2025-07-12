output "app_url" {
  value = "http://${aws_ecs_service.service.name}.elb.amazonaws.com:9000"
}