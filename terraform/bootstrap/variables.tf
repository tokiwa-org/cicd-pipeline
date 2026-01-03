variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cicd-pipeline"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "tokiwa-org"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "cicd-pipeline"
}
