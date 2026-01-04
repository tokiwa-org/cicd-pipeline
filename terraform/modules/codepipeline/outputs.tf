# =============================================================================
# Deployment Artifacts
# =============================================================================

output "artifacts_bucket_name" {
  description = "S3 artifacts bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "S3 artifacts bucket ARN"
  value       = aws_s3_bucket.artifacts.arn
}

# =============================================================================
# DEPRECATED OUTPUTS
# =============================================================================
# The following outputs are deprecated and will be removed in a future version.
# They are kept for backward compatibility during migration from CodeDeploy.
# =============================================================================

output "pipeline_name" {
  description = "DEPRECATED: CodePipeline removed - use ECS native deployment"
  value       = null
}

output "pipeline_arn" {
  description = "DEPRECATED: CodePipeline removed - use ECS native deployment"
  value       = null
}

output "codedeploy_app_name" {
  description = "DEPRECATED: CodeDeploy removed - use ECS native deployment"
  value       = null
}

output "deployment_group_name" {
  description = "DEPRECATED: CodeDeploy removed - use ECS native deployment"
  value       = null
}
