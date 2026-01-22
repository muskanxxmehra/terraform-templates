################################################################################
# AWS App + Oracle XE DB Service (Docker Compose on Ubuntu)
# 
# This Terraform configuration:
# - Provisions VPC, Security Groups, IAM
# - Creates DB server with Oracle XE 21c via Docker Compose
# - Creates App server with Flask application (Python + oracledb)
# - Seeds sample data (USERS, ORDERS)
#
# Everything is automated via user_data scripts!
#
# Database Server Includes:
# - Docker & Docker Compose
# - Oracle XE 21c (gvenzl/oracle-xe:21-slim)
# - AWS CLI v2 (pre-configured if credentials provided)
# - Oracle Instant Client (for impdp/expdp)
#
# IMPORTANT: Oracle XE requires:
# - Minimum t3.medium instance (2 vCPU, 4GB RAM)
# - Minimum 20GB root volume
# - Port 1521 for Oracle Listener
################################################################################

terraform {
  required_version = ">= 1.0.0"

  # ============================================================================
  # TERRAFORM CLOUD BACKEND (Optional - uncomment and configure if using TF Cloud)
  # ============================================================================
  # cloud {
  #   organization = "YOUR_ORG_NAME"  # Change this
  #
  #   workspaces {
  #     name = "aws-app-oracle-db-docker"  # Change this
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
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
      Service     = "aws-app-oracle-db-docker"
      Database    = "Oracle XE 21c (Docker)"
    }
  }
}

################################################################################
# Data Sources
################################################################################

# Ubuntu 24.04 LTS AMI (recommended for Docker)
data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Ubuntu 22.04 LTS AMI (alternative)
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# Local Values
################################################################################

locals {
  # Choose Ubuntu version based on variable
  ami_id = var.use_ubuntu_24 ? data.aws_ami.ubuntu_24.id : data.aws_ami.ubuntu_22.id
}

################################################################################
# Modules
################################################################################

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = data.aws_availability_zones.available.names[0]
  environment        = var.environment
  tags               = var.tags
}

module "iam" {
  source = "../../modules/iam"

  environment = var.environment
  tags        = var.tags
}

module "security" {
  source = "../../modules/security"

  vpc_id           = module.vpc.vpc_id
  environment      = var.environment
  ssh_allowed_cidr = var.ssh_allowed_cidr
  app_port         = var.app_port
  db_port          = var.db_port  # 1521 for Oracle
  tags             = var.tags
}

# Oracle XE DB Server (Docker Compose) - Must be created FIRST
module "db" {
  source = "../../modules/ec2-db"

  ami_id               = local.ami_id
  instance_type        = var.db_instance_type  # Minimum t3.medium for Oracle XE
  subnet_id            = module.vpc.public_subnet_id
  security_group_id    = module.security.db_sg_id
  key_name             = var.key_name
  iam_instance_profile = module.iam.instance_profile_name
  environment          = var.environment
  root_volume_size     = var.db_volume_size  # Minimum 20GB for Oracle XE
  db_user              = var.db_user
  db_password          = var.db_password
  aws_region           = var.aws_region
  aws_access_key_id    = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  tags                 = var.tags
}


# STEP 5 - S3 Bucket for Data Pump exports

resource "aws_s3_bucket" "demo_bucket" {
  bucket = var.s3_bucket_name

  tags = merge(var.tags, {
    Name = var.s3_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# App Server - Created AFTER DB (needs DB private IP)
module "app" {
  source = "../../modules/ec2-app"

  ami_id               = local.ami_id
  instance_type        = var.app_instance_type
  subnet_id            = module.vpc.public_subnet_id
  security_group_id    = module.security.app_sg_id
  key_name             = var.key_name
  iam_instance_profile = module.iam.instance_profile_name
  app_name             = var.app_name
  environment          = var.environment
  root_volume_size     = var.app_volume_size
  create_eip           = var.create_app_eip
  app_port             = var.app_port
  
  # Oracle Database connection info (passed to user_data)
  db_host     = module.db.private_ip
  db_port     = var.db_port
  db_service  = var.db_service
  db_user     = var.db_user
  db_password = var.db_password
  
  tags = var.tags

  # Explicit dependency - wait for DB to be ready
  depends_on = [module.db]
}

