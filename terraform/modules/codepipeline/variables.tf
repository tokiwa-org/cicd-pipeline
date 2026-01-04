variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# =============================================================================
# NOTE: The following variables are no longer needed with ECS native blue/green
# They are kept for backward compatibility but can be removed after migration
# =============================================================================

variable "ecs_cluster_name" {
  description = "DEPRECATED: ECS cluster name (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "DEPRECATED: ECS service name (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "listener_arn" {
  description = "DEPRECATED: ALB production listener ARN (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "test_listener_arn" {
  description = "DEPRECATED: ALB test listener ARN (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "target_group_blue_name" {
  description = "DEPRECATED: Blue target group name (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "target_group_green_name" {
  description = "DEPRECATED: Green target group name (not needed for ECS native deployment)"
  type        = string
  default     = ""
}

variable "termination_wait_time" {
  description = "DEPRECATED: Use bake_time_in_minutes in ECS module instead"
  type        = number
  default     = 5
}

variable "require_approval" {
  description = "DEPRECATED: Approval workflow should be handled in GitHub Actions"
  type        = bool
  default     = false
}
