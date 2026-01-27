################################################################################
# AWS App + Oracle XE DB Service (Docker) - Example Variables
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
key_name         = "my-key-pair"
ssh_allowed_cidr = ["0.0.0.0/0"]
app_port         = 5000
db_port          = 1521

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
use_ubuntu_24               = true
db_instance_type            = "t3.medium"
db_volume_size              = 30
db_service                  = "XEPDB1"
db_user                     = "appuser"
db_password                 = "Azalio123456"
db_elastic_ip_allocation_id = "eipalloc-0bce288fb29cb7bd4"

#------------------------------------------------------------------------------
# S3 Bucket for Data Pump exports
#------------------------------------------------------------------------------
s3_bucket_name = "cfwdemobucket"
