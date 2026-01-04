# Environment-specific variables
aws_region     = "ap-northeast-1"
project_name   = "cicd-pipeline"
environment    = "staging"
vpc_cidr       = "10.1.0.0/16"
container_port = 3000
container_cpu  = 256
container_memory = 512
desired_count  = 2
launch_type    = "fargate"  # fargate or ec2

# GitHub OIDC is now managed in terraform/bootstrap/
