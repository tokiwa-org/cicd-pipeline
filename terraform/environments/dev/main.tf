terraform {
  backend "s3" {
    bucket         = "cicd-pipeline-terraform-state-442426898844"
    key            = "cicd-pipeline/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "cicd-pipeline-terraform-lock"
  }

  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  environment = "dev"
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = local.environment
}

module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port    = var.container_port
  health_check_path = "/health"
}

module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = local.environment
  aws_region            = var.aws_region
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_blue_arn
  ecr_repository_url    = module.ecr.repository_url
  container_port        = var.container_port
  container_cpu         = var.container_cpu
  container_memory      = var.container_memory
  desired_count         = var.desired_count

  # ECS Launch Type Configuration
  launch_type          = var.launch_type
  ec2_instance_type    = var.ec2_instance_type
  ec2_desired_capacity = var.ec2_desired_capacity
  ec2_min_capacity     = var.ec2_min_capacity
  ec2_max_capacity     = var.ec2_max_capacity
}

module "codepipeline" {
  source = "../../modules/codepipeline"

  project_name            = var.project_name
  environment             = local.environment
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  listener_arn            = module.alb.listener_arn
  test_listener_arn       = module.alb.test_listener_arn
  target_group_blue_name  = module.alb.target_group_blue_name
  target_group_green_name = module.alb.target_group_green_name
  termination_wait_time   = 1
  require_approval        = false
  # NOTE: GitHub OIDC is now managed in terraform/bootstrap/
}
