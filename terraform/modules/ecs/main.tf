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
# IAM Role for ECS Blue/Green Deployment (manages target groups)
# =============================================================================

resource "aws_iam_role" "ecs_bluegreen" {
  count = var.deployment_strategy == "BLUE_GREEN" ? 1 : 0
  name  = "${local.name_prefix}-ecs-bluegreen-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-bluegreen-role"
  }
}

resource "aws_iam_role_policy" "ecs_bluegreen" {
  count = var.deployment_strategy == "BLUE_GREEN" ? 1 : 0
  name  = "${local.name_prefix}-ecs-bluegreen-policy"
  role  = aws_iam_role.ecs_bluegreen[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
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

# Get latest ECS-optimized AMI (only needed for EC2 launch type with self-managed ASG)
data "aws_ssm_parameter" "ecs_ami" {
  count = var.launch_type == "ec2" ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# Launch Template for EC2 instances (only for self-managed EC2 with ASG)
resource "aws_launch_template" "ecs" {
  count         = var.launch_type == "ec2" ? 1 : 0
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

# Auto Scaling Group for EC2 instances (only for self-managed EC2)
resource "aws_autoscaling_group" "ecs" {
  count               = var.launch_type == "ec2" ? 1 : 0
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

# ECS Capacity Provider for EC2 (only for self-managed EC2 with ASG)
resource "aws_ecs_capacity_provider" "ec2" {
  count = var.launch_type == "ec2" ? 1 : 0
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
# Managed Instances Infrastructure (only created when launch_type is managed_instances)
# =============================================================================

# IAM Role for ECS to manage EC2 instances
resource "aws_iam_role" "ecs_infrastructure" {
  count = var.launch_type == "managed_instances" ? 1 : 0
  name  = "${local.name_prefix}-ecs-infrastructure-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-infrastructure-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  count      = var.launch_type == "managed_instances" ? 1 : 0
  role       = aws_iam_role.ecs_infrastructure[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForManagedInstances"
}

# ECS Capacity Provider for Managed Instances
# Note: The 'cluster' parameter is required - capacity provider is automatically associated at creation
resource "aws_ecs_capacity_provider" "managed_instances" {
  count   = var.launch_type == "managed_instances" ? 1 : 0
  name    = "${local.name_prefix}-managed-cp"
  cluster = aws_ecs_cluster.main.name

  managed_instances_provider {
    infrastructure_role_arn = aws_iam_role.ecs_infrastructure[0].arn

    instance_launch_template {
      ec2_instance_profile_arn = aws_iam_instance_profile.ecs_instance[0].arn

      network_configuration {
        subnets         = var.private_subnet_ids
        security_groups = [aws_security_group.ecs_instances[0].id]
      }

      instance_requirements {
        vcpu_count {
          min = var.managed_instances_vcpu_range.min
          max = var.managed_instances_vcpu_range.max
        }
        memory_mib {
          min = var.managed_instances_memory_range.min
          max = var.managed_instances_memory_range.max
        }
        cpu_manufacturers = ["amazon-web-services", "intel", "amd"]
      }
    }
  }

  tags = {
    Name = "${local.name_prefix}-managed-capacity-provider"
  }
}

# =============================================================================
# ECS Cluster Capacity Providers
# =============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  # Note: Managed Instances capacity providers are automatically associated with the cluster
  # at creation time and should NOT be included in this list (AWS API limitation)
  capacity_providers = concat(
    ["FARGATE", "FARGATE_SPOT"],
    var.launch_type == "ec2" ? [aws_ecs_capacity_provider.ec2[0].name] : []
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

  # Managed Instances mode: set Managed Instances as default
  dynamic "default_capacity_provider_strategy" {
    for_each = var.launch_type == "managed_instances" ? [1] : []
    content {
      base              = 1
      weight            = 100
      capacity_provider = aws_ecs_capacity_provider.managed_instances[0].name
    }
  }

  # Ensure cluster capacity providers are created after Managed Instances CP
  depends_on = [aws_ecs_capacity_provider.managed_instances]
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

# ECS Service with Native Blue/Green Deployment
resource "aws_ecs_service" "main" {
  name                               = "${local.name_prefix}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.desired_count
  platform_version                   = var.launch_type == "fargate" ? "LATEST" : null
  health_check_grace_period_seconds  = 60

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

  # Managed Instances mode: Use Managed Instances capacity provider
  dynamic "capacity_provider_strategy" {
    for_each = var.launch_type == "managed_instances" ? [1] : []
    content {
      capacity_provider = aws_ecs_capacity_provider.managed_instances[0].name
      weight            = 100
      base              = 1
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # Load balancer configuration with Blue/Green advanced_configuration
  load_balancer {
    target_group_arn = var.target_group_blue_arn
    container_name   = "${local.name_prefix}-app"
    container_port   = var.container_port

    # Required for BLUE_GREEN deployment strategy
    dynamic "advanced_configuration" {
      for_each = var.deployment_strategy == "BLUE_GREEN" ? [1] : []
      content {
        alternate_target_group_arn = var.target_group_green_arn
        production_listener_rule   = var.production_listener_rule_arn
        test_listener_rule         = var.test_listener_rule_arn != "" ? var.test_listener_rule_arn : null
        role_arn                   = aws_iam_role.ecs_bluegreen[0].arn
      }
    }
  }

  # ECS native deployment controller (required for native blue/green)
  deployment_controller {
    type = "ECS"
  }

  # Deployment limits (top-level arguments)
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Circuit breaker for automatic rollback (top-level block)
  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker_enabled
    rollback = var.deployment_circuit_breaker_enabled
  }

  # Native Blue/Green or Rolling deployment configuration
  deployment_configuration {
    # Deployment strategy: ROLLING or BLUE_GREEN
    strategy = var.deployment_strategy

    # Bake time for blue/green validation (only applies to BLUE_GREEN)
    bake_time_in_minutes = var.deployment_strategy == "BLUE_GREEN" ? var.bake_time_in_minutes : null
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
      platform_version,
      capacity_provider_strategy
    ]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}
