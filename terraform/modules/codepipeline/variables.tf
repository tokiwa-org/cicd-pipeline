variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "listener_arn" {
  description = "ALB production listener ARN"
  type        = string
}

variable "test_listener_arn" {
  description = "ALB test listener ARN"
  type        = string
}

variable "target_group_blue_name" {
  description = "Blue target group name"
  type        = string
}

variable "target_group_green_name" {
  description = "Green target group name"
  type        = string
}

variable "termination_wait_time" {
  description = "Time in minutes to wait before terminating blue instances"
  type        = number
  default     = 5
}

variable "require_approval" {
  description = "Whether to require manual approval before deployment"
  type        = bool
  default     = false
}

# NOTE: github_owner, github_repo, create_github_oidc variables removed
# GitHub OIDC is now managed in terraform/bootstrap/
