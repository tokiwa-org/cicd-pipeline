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
  default     = "staging"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
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
  default     = 2
}

# ECS Launch Type Configuration
variable "launch_type" {
  description = "ECS launch type: fargate or ec2"
  type        = string
  default     = "fargate"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS (used when launch_type is ec2)"
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

# NOTE: github_owner and github_repo removed
# GitHub OIDC is now managed in terraform/bootstrap/
