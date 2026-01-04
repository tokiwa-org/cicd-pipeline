locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# ECS Native Blue/Green Deployment
# =============================================================================
# NOTE: CodeDeploy and CodePipeline have been removed.
# ECS now handles blue/green deployments natively (announced July 2025).
#
# Deployment is triggered by:
# 1. GitHub Actions registers new task definition
# 2. GitHub Actions calls `aws ecs update-service` with new task definition
# 3. ECS performs native blue/green deployment with bake time validation
#
# See: https://aws.amazon.com/about-aws/whats-new/2025/07/amazon-ecs-built-in-blue-green-deployments/
# =============================================================================

data "aws_caller_identity" "current" {}

# S3 Bucket for Deployment Artifacts (optional, for logs/artifacts storage)
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name_prefix}-deployment-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-deployment-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule to clean up old artifacts
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "cleanup-old-artifacts"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
