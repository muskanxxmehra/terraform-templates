################################################################################
# AWS App + Oracle XE DB Service (Docker) - Example Variables
# 
# Copy this file to terraform.tfvars and update values as needed
# WARNING: Do NOT commit terraform.tfvars with real credentials to version control!
################################################################################

#------------------------------------------------------------------------------
# General Settings
#------------------------------------------------------------------------------
aws_region   = "ap-south-1"
project_name = "webapp-oracle-docker"
environment  = "dev"

tags = {
  Owner      = "your-name"
  CostCenter = "your-cost-center"
}

#------------------------------------------------------------------------------
# Network Settings
#------------------------------------------------------------------------------
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

#------------------------------------------------------------------------------
# Security Settings
#------------------------------------------------------------------------------
# Name of your existing SSH key pair in AWS
key_name = "your-key-name"

# Restrict SSH access to your IP only (recommended for production)
# Use ["0.0.0.0/0"] only for development/testing
ssh_allowed_cidr = ["0.0.0.0/0"]

# Application port
app_port = 5000

# Oracle listener port
db_port = 1521

#------------------------------------------------------------------------------
# Application Server Settings
#------------------------------------------------------------------------------
app_name          = "flask-oracle-app"
app_instance_type = "t2.micro"
app_volume_size   = 8
create_app_eip    = false

#------------------------------------------------------------------------------
# Oracle XE Database Server Settings (Docker)
#------------------------------------------------------------------------------
# Use Ubuntu 24.04 LTS (recommended) or 22.04
use_ubuntu_24 = true

# Minimum t3.medium required for Oracle XE
db_instance_type = "t3.medium"

# Minimum 20GB required for Oracle XE, 30GB recommended
db_volume_size = 30

# Oracle service name (default is XEPDB1)
db_service = "XEPDB1"

# Database user (created automatically)
db_user = "appuser"

# Database password (must meet Oracle requirements)
# - Minimum 8 characters
# - Must include uppercase, lowercase, and numbers
db_password = "Azalio123456"

# Existing Elastic IP allocation ID for DB server
# Find yours with: aws ec2 describe-addresses --query "Addresses[*].[PublicIp,AllocationId]" --output table
db_elastic_ip_allocation_id = "eipalloc-0bce288fb29cb7bd4"

#------------------------------------------------------------------------------
# S3 Bucket for Data Pump exports
#------------------------------------------------------------------------------
s3_bucket_name = "your-unique-bucket-name"

#------------------------------------------------------------------------------
# AWS CLI Configuration (Optional)
# Used for Data Pump S3 integration
# Leave empty if not needed
#------------------------------------------------------------------------------
# aws_access_key_id     = "YOUR_ACCESS_KEY_ID"
# aws_secret_access_key = "YOUR_SECRET_ACCESS_KEY"
