data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_ecr_repository" "orders" {
  name = "${var.project_name}-orders"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}
resource "aws_ecr_repository" "catalog" {
  name = "${var.project_name}-catalog"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}
resource "aws_ecr_repository" "gateway" {
  name = "${var.project_name}-gateway"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each = {
    orders = aws_ecr_repository.orders.name
    catalog = aws_ecr_repository.catalog.name
    gateway = aws_ecr_repository.gateway.name
  }
  repository = each.value
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Keep the newest 10 tagged builds", selection = { tagStatus = "tagged", tagPatternList = ["*"], countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }] })
}

resource "aws_security_group" "service" {
  name = "${var.project_name}-service"
  description = "Restricted public access to the demo gateway"
  vpc_id = data.aws_vpc.default.id
  ingress {
    description = "Demo HTTP endpoint"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

resource "aws_iam_role" "execution" {
  name = "${var.project_name}-execution"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags = local.tags
}
resource "aws_iam_role_policy_attachment" "execution" {
  role = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "demo" {
  name = var.project_name
  tags = local.tags
}
resource "aws_ecs_task_definition" "demo" {
  family = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "512"
  memory = "1024"
  execution_role_arn = aws_iam_role.execution.arn
  container_definitions = jsonencode([
    { name = "orders", image = "${aws_ecr_repository.orders.repository_url}:${var.image_tag}", essential = true, cpu = 128, memory = 256, portMappings = [{ containerPort = 8000, protocol = "tcp" }], healthCheck = { command = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')\""], interval = 30, timeout = 5, retries = 3, startPeriod = 20 } },
    { name = "catalog", image = "${aws_ecr_repository.catalog.repository_url}:${var.image_tag}", essential = true, cpu = 128, memory = 256, portMappings = [{ containerPort = 8001, protocol = "tcp" }], healthCheck = { command = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health')\""], interval = 30, timeout = 5, retries = 3, startPeriod = 20 } },
    { name = "gateway", image = "${aws_ecr_repository.gateway.repository_url}:${var.image_tag}", essential = true, cpu = 128, memory = 128, portMappings = [{ containerPort = 8080, protocol = "tcp" }], dependsOn = [{ containerName = "orders", condition = "HEALTHY" }, { containerName = "catalog", condition = "HEALTHY" }], healthCheck = { command = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1"], interval = 30, timeout = 5, retries = 3, startPeriod = 10 } }
  ])
  tags = local.tags
}
resource "aws_ecs_service" "demo" {
  name = var.project_name
  cluster = aws_ecs_cluster.demo.id
  task_definition = aws_ecs_task_definition.demo.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent = 100
  network_configuration {
    subnets = data.aws_subnets.public.ids
    assign_public_ip = true
    security_groups = [aws_security_group.service.id]
  }
  depends_on = [aws_iam_role_policy_attachment.execution]
  tags = local.tags
}
