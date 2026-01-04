variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cicd-pipeline"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Fargate CPU units"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Fargate memory in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 3
}

# ECS Launch Type Configuration
variable "launch_type" {
  description = "ECS launch type: fargate, ec2, or managed_instances"
  type        = string
  default     = "fargate"
}

# Managed Instances Configuration (used when launch_type is managed_instances)
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

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS (used when launch_type is ec2)"
  type        = string
  default     = "t3.medium"
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances in ASG"
  type        = number
  default     = 3
}

variable "ec2_min_capacity" {
  description = "Minimum number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "ec2_max_capacity" {
  description = "Maximum number of EC2 instances in ASG"
  type        = number
  default     = 6
}

# Blue/Green Deployment Configuration (ECS native)
variable "deployment_strategy" {
  description = "ECS deployment strategy: ROLLING or BLUE_GREEN"
  type        = string
  default     = "BLUE_GREEN"
}

variable "bake_time_in_minutes" {
  description = "Bake time for blue/green deployment validation (0-1440 minutes)"
  type        = number
  default     = 10  # Longer bake time for production
}

# NOTE: github_owner and github_repo removed
# GitHub OIDC is now managed in terraform/bootstrap/
