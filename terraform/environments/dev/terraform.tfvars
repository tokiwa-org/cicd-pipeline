# Environment-specific variables
aws_region     = "ap-northeast-1"
project_name   = "cicd-pipeline"
environment    = "dev"
vpc_cidr       = "10.0.0.0/16"
container_port = 3000
container_cpu  = 256
container_memory = 512
desired_count  = 1
launch_type    = "fargate"  # fargate, ec2, or managed_instances

# EC2 launch type configuration (uncomment when launch_type = "ec2")
# ec2_instance_type    = "t3.micro"
# ec2_desired_capacity = 1
# ec2_min_capacity     = 1
# ec2_max_capacity     = 2

# Managed Instances configuration
managed_instances_vcpu_range   = { min = 1, max = 2 }
managed_instances_memory_range = { min = 1024, max = 4096 }

# GitHub OIDC is now managed in terraform/bootstrap/
