# Environment-specific variables
aws_region     = "ap-northeast-1"
project_name   = "cicd-pipeline"
environment    = "prod"
vpc_cidr       = "10.2.0.0/16"
container_port = 3000
container_cpu  = 512
container_memory = 1024
desired_count  = 3

# GitHub configuration - UPDATE THESE VALUES
github_owner = "your-github-username"
github_repo  = "cicd-pipeline"
