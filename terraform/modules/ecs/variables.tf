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

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
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
  description = "ECS launch type: fargate (serverless) or ec2 (self-managed instances)"
  type        = string
  default     = "fargate"

  validation {
    condition     = contains(["fargate", "ec2"], var.launch_type)
    error_message = "launch_type must be fargate or ec2"
  }
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
