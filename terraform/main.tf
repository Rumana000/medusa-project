provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app" {
  name                 = "medusa-app"
  image_tag_mutability = "MUTABLE"  # Allows same tag overwrites

  image_scanning_configuration {
    scan_on_push = true  # Enable vulnerability scanning
  }
}

resource "aws_db_instance" "medusa_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.4"  # Explicit version
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false   # Critical for security!
  storage_encrypted      = true    # Enable encryption

  lifecycle {
    prevent_destroy = false  # Allow terraform destroy
  }
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
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn  # Required for Fargate

  container_definitions = jsonencode([{
    name      = "medusa",
    image     = var.image_uri,
    essential = true,
    portMappings = [{
      containerPort = 9000,
      hostPort      = 9000,
      protocol      = "tcp"
    }],
    environment = [
      {
        name  = "DATABASE_URL",
        value = "postgres://${var.db_user}:${var.db_password}@${aws_db_instance.medusa_db.endpoint}/${var.db_name}"
      },
      {
        name  = "NODE_ENV",
        value = "production"
      }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = "/ecs/medusa",
        "awslogs-region"        = var.aws_region,
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true  # Required for Fargate with public subnets
  }

  depends_on = [aws_db_instance.medusa_db]
}

# Required additional resources (add to your file)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs" {
  name        = "medusa-ecs-sg"
  description = "Allow Medusa traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "medusa-rds-sg"
  description = "Allow ECS to access RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]  # Only allow ECS
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "medusa-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}