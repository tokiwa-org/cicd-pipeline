output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Task definition family"
  value       = aws_ecs_task_definition.main.family
}

output "task_execution_role_arn" {
  description = "Task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "Task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "security_group_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

# Launch Type Configuration
output "launch_type" {
  description = "ECS launch type (fargate, ec2, or managed_instances)"
  value       = var.launch_type
}

# EC2 Infrastructure outputs (only populated when launch_type is ec2)
output "ec2_capacity_provider_name" {
  description = "EC2 capacity provider name (self-managed)"
  value       = var.launch_type == "ec2" ? aws_ecs_capacity_provider.ec2[0].name : null
}

output "ec2_asg_name" {
  description = "Auto Scaling Group name for EC2 instances"
  value       = var.launch_type == "ec2" ? aws_autoscaling_group.ecs[0].name : null
}

output "ec2_asg_arn" {
  description = "Auto Scaling Group ARN for EC2 instances"
  value       = var.launch_type == "ec2" ? aws_autoscaling_group.ecs[0].arn : null
}

output "ec2_launch_template_id" {
  description = "Launch template ID for EC2 instances"
  value       = var.launch_type == "ec2" ? aws_launch_template.ecs[0].id : null
}

output "ec2_instance_security_group_id" {
  description = "Security group ID for EC2/Managed instances"
  value       = var.launch_type != "fargate" ? aws_security_group.ecs_instances[0].id : null
}

# Managed Instances outputs (only populated when launch_type is managed_instances)
output "managed_instances_capacity_provider_name" {
  description = "Managed Instances capacity provider name"
  value       = var.launch_type == "managed_instances" ? aws_ecs_capacity_provider.managed_instances[0].name : null
}

output "managed_instances_infrastructure_role_arn" {
  description = "IAM role ARN for ECS Managed Instances infrastructure"
  value       = var.launch_type == "managed_instances" ? aws_iam_role.ecs_infrastructure[0].arn : null
}

# Deployment Configuration
output "deployment_strategy" {
  description = "ECS deployment strategy (ROLLING or BLUE_GREEN)"
  value       = var.deployment_strategy
}

output "deployment_controller_type" {
  description = "ECS deployment controller type"
  value       = "ECS"
}

output "bake_time_in_minutes" {
  description = "Bake time for blue/green deployment validation"
  value       = var.deployment_strategy == "BLUE_GREEN" ? var.bake_time_in_minutes : null
}
