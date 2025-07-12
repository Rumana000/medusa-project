provider "aws" {
  region = "us-east-1" # Hardcode if this is just for testing
}

# 1. ECR Repository (simplified)
resource "aws_ecr_repository" "app" {
  name = "medusa-app" # Remove scanning to speed up deployment
}

# 2. Database (minimum viable)
resource "aws_db_instance" "medusa_db" {
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  db_name              = "medusa" # Hardcode if not reusing
  username             = "medusa_admin" # Hardcode if not reusing
  password             = var.db_password
  skip_final_snapshot  = true
  publicly_accessible  = false
}

# 3. ECS Cluster (minimum)
resource "aws_ecs_cluster" "cluster" {
  name = "medusa-cluster"
}

# 4. Task Definition (simplified)
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
    portMappings = [{ 
      containerPort = 9000 
    }],
    environment = [
      {
        name  = "DATABASE_URL",
        value = "postgres://medusa_admin:${var.db_password}@${aws_db_instance.medusa_db.endpoint}/medusa"
      }
    ]
  }])
}

# 5. ECS Service (minimum)
resource "aws_ecs_service" "service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}

# 6. Security Groups (minimum)
resource "aws_security_group" "ecs" {
  name        = "medusa-ecs-sg"
  description = "Allow Medusa traffic"

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}