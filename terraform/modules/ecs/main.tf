locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

# =============================================================================
# EC2 Infrastructure (only created when launch_type is ec2)
# =============================================================================

# IAM Role for EC2 Instances
resource "aws_iam_role" "ecs_instance" {
  count = var.launch_type != "fargate" ? 1 : 0
  name  = "${local.name_prefix}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  count      = var.launch_type != "fargate" ? 1 : 0
  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  count      = var.launch_type != "fargate" ? 1 : 0
  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  count = var.launch_type != "fargate" ? 1 : 0
  name  = "${local.name_prefix}-ecs-instance-profile"
  role  = aws_iam_role.ecs_instance[0].name

  tags = {
    Name = "${local.name_prefix}-ecs-instance-profile"
  }
}

# Security Group for EC2 Instances
resource "aws_security_group" "ecs_instances" {
  count       = var.launch_type != "fargate" ? 1 : 0
  name        = "${local.name_prefix}-ecs-instances-sg"
  description = "Security group for ECS EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-instances-sg"
  }
}

# Get latest ECS-optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  count = var.launch_type != "fargate" ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# Launch Template for EC2 instances
resource "aws_launch_template" "ecs" {
  count         = var.launch_type != "fargate" ? 1 : 0
  name_prefix   = "${local.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami[0].value
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance[0].name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_instances[0].id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-ecs-instance"
    }
  }

  tags = {
    Name = "${local.name_prefix}-ecs-launch-template"
  }
}

# Auto Scaling Group for EC2 instances
resource "aws_autoscaling_group" "ecs" {
  count               = var.launch_type != "fargate" ? 1 : 0
  name                = "${local.name_prefix}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  desired_capacity    = var.ec2_desired_capacity
  min_size            = var.ec2_min_capacity
  max_size            = var.ec2_max_capacity

  launch_template {
    id      = aws_launch_template.ecs[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Capacity Provider for EC2
resource "aws_ecs_capacity_provider" "ec2" {
  count = var.launch_type != "fargate" ? 1 : 0
  name  = "${local.name_prefix}-ec2-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs[0].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 10
    }
  }

  tags = {
    Name = "${local.name_prefix}-ec2-capacity-provider"
  }
}

# =============================================================================
# ECS Cluster Capacity Providers
# =============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = concat(
    ["FARGATE", "FARGATE_SPOT"],
    var.launch_type != "fargate" ? [aws_ecs_capacity_provider.ec2[0].name] : []
  )

  # Fargate-only mode: set FARGATE as default
  dynamic "default_capacity_provider_strategy" {
    for_each = var.launch_type == "fargate" ? [1] : []
    content {
      base              = 1
      weight            = 100
      capacity_provider = "FARGATE"
    }
  }

  # EC2 mode: set EC2 as default
  dynamic "default_capacity_provider_strategy" {
    for_each = var.launch_type == "ec2" ? [1] : []
    content {
      base              = 1
      weight            = 100
      capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    }
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-tasks-sg"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-logs"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-role"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = var.launch_type == "fargate" ? ["FARGATE"] : ["FARGATE", "EC2"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "${local.name_prefix}-app"
      image = "${var.ecr_repository_url}:latest"
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        }
      ]
    }
  ])

  tags = {
    Name = "${local.name_prefix}-task"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name                               = "${local.name_prefix}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.desired_count
  platform_version                   = var.launch_type == "fargate" ? "LATEST" : null
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Fargate-only mode
  dynamic "capacity_provider_strategy" {
    for_each = var.launch_type == "fargate" ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 100
      base              = 1
    }
  }

  # EC2 mode: Use EC2 capacity provider
  dynamic "capacity_provider_strategy" {
    for_each = var.launch_type == "ec2" ? [1] : []
    content {
      capacity_provider = aws_ecs_capacity_provider.ec2[0].name
      weight            = 100
      base              = 1
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "${local.name_prefix}-app"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
      load_balancer,
      platform_version,
      capacity_provider_strategy
    ]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}
