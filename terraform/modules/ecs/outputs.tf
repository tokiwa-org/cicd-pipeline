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

# EC2 Infrastructure outputs (only populated when launch_type is ec2)
output "launch_type" {
  description = "ECS launch type (fargate or ec2)"
  value       = var.launch_type
}

output "ec2_capacity_provider_name" {
  description = "EC2 capacity provider name"
  value       = var.launch_type != "fargate" ? aws_ecs_capacity_provider.ec2[0].name : null
}

output "ec2_asg_name" {
  description = "Auto Scaling Group name for EC2 instances"
  value       = var.launch_type != "fargate" ? aws_autoscaling_group.ecs[0].name : null
}

output "ec2_asg_arn" {
  description = "Auto Scaling Group ARN for EC2 instances"
  value       = var.launch_type != "fargate" ? aws_autoscaling_group.ecs[0].arn : null
}

output "ec2_launch_template_id" {
  description = "Launch template ID for EC2 instances"
  value       = var.launch_type != "fargate" ? aws_launch_template.ecs[0].id : null
}

output "ec2_instance_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = var.launch_type != "fargate" ? aws_security_group.ecs_instances[0].id : null
}
