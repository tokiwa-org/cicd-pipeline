output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "pipeline_name" {
  description = "CodePipeline name"
  value       = module.codepipeline.pipeline_name
}

output "artifacts_bucket_name" {
  description = "S3 artifacts bucket name"
  value       = module.codepipeline.artifacts_bucket_name
}

# NOTE: github_actions_role_arn is now managed in terraform/bootstrap/

# ECS Launch Type Outputs
output "ecs_launch_type" {
  description = "ECS launch type (fargate or ec2)"
  value       = module.ecs.launch_type
}

output "ec2_asg_name" {
  description = "Auto Scaling Group name for EC2 instances (null if fargate-only)"
  value       = module.ecs.ec2_asg_name
}
