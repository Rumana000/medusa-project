provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app" {
  name = "medusa-app"
}

resource "aws_db_instance" "medusa_db" {
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  skip_final_snapshot  = true
}

resource "aws_ecs_cluster" "cluster" {
  name = "medusa-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "medusa-task"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  
  container_definitions = jsonencode([{
    name      = "medusa",
    image     = var.image_uri,
    essential = true,
    portMappings = [{ containerPort = 9000 }],
    environment = [
      {
        name  = "DATABASE_URL",
        value = "postgres://${var.db_user}:${var.db_password}@${aws_db_instance.medusa_db.endpoint}/${var.db_name}"
      }
    ]
  }])
}

resource "aws_ecs_service" "service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
}