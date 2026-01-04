variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

# Deprecated: Use target_group_blue_arn and target_group_green_arn instead
# Kept for backward compatibility during migration
variable "target_group_arn" {
  description = "DEPRECATED: Use target_group_blue_arn instead"
  type        = string
  default     = ""
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Fargate CPU units"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Fargate memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

# Launch type configuration
variable "launch_type" {
  description = "ECS launch type: fargate (serverless), ec2 (self-managed instances), or managed_instances (AWS-managed EC2)"
  type        = string
  default     = "fargate"

  validation {
    condition     = contains(["fargate", "ec2", "managed_instances"], var.launch_type)
    error_message = "launch_type must be fargate, ec2, or managed_instances"
  }
}

# Managed Instances configuration (used when launch_type is managed_instances)
variable "managed_instances_vcpu_range" {
  description = "vCPU range for managed instances"
  type = object({
    min = number
    max = number
  })
  default = { min = 1, max = 4 }
}

variable "managed_instances_memory_range" {
  description = "Memory range (MiB) for managed instances"
  type = object({
    min = number
    max = number
  })
  default = { min = 2048, max = 8192 }
}

# EC2 configuration (used when launch_type is ec2)
variable "ec2_instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "t3.medium"
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "ec2_min_capacity" {
  description = "Minimum number of EC2 instances in ASG"
  type        = number
  default     = 1
}

variable "ec2_max_capacity" {
  description = "Maximum number of EC2 instances in ASG"
  type        = number
  default     = 4
}

# Blue/Green Deployment Configuration (ECS native)
variable "deployment_strategy" {
  description = "ECS deployment strategy: ROLLING or BLUE_GREEN"
  type        = string
  default     = "BLUE_GREEN"

  validation {
    condition     = contains(["ROLLING", "BLUE_GREEN"], var.deployment_strategy)
    error_message = "deployment_strategy must be ROLLING or BLUE_GREEN"
  }
}

variable "bake_time_in_minutes" {
  description = "Bake time for blue/green deployment validation (0-1440 minutes)"
  type        = number
  default     = 5

  validation {
    condition     = var.bake_time_in_minutes >= 0 && var.bake_time_in_minutes <= 1440
    error_message = "bake_time_in_minutes must be between 0 and 1440"
  }
}

variable "deployment_circuit_breaker_enabled" {
  description = "Enable deployment circuit breaker for automatic rollback"
  type        = bool
  default     = true
}

variable "target_group_blue_arn" {
  description = "Blue target group ARN for blue/green deployment"
  type        = string
}

variable "target_group_green_arn" {
  description = "Green target group ARN for blue/green deployment"
  type        = string
}

variable "production_listener_rule_arn" {
  description = "Production listener rule ARN for blue/green deployment"
  type        = string
  default     = ""
}

variable "test_listener_rule_arn" {
  description = "Test listener rule ARN for blue/green deployment (optional)"
  type        = string
  default     = ""
}
