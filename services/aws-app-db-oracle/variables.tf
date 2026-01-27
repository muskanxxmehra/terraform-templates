################################################################################
# AWS App + Oracle XE DB Service (Docker) - Variables
# Configure in Terraform Cloud or terraform.tfvars
################################################################################

#------------------------------------------------------------------------------
# General Settings
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "webapp-oracle-docker-project"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Network Settings
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

#------------------------------------------------------------------------------
# Security Settings
#------------------------------------------------------------------------------

variable "key_name" {
  description = "Name of the SSH key pair for EC2 instances"
  type        = string
}

variable "private_key_path" {
  description = "Path to SSH private key file for connecting to EC2 instances (used by null_resource to wait for DB)"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 5000
}

variable "db_port" {
  description = "Oracle database listener port"
  type        = number
  default     = 1521
}

#------------------------------------------------------------------------------
# Application Server Settings
#------------------------------------------------------------------------------

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "flask-oracle-app"
}

variable "app_instance_type" {
  description = "EC2 instance type for app server"
  type        = string
  default     = "t2.micro"
}

variable "app_volume_size" {
  description = "Root volume size in GB for app server"
  type        = number
  default     = 8
}

variable "create_app_eip" {
  description = "Whether to create an Elastic IP for the app server"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Oracle XE Database Server Settings (Docker)
#------------------------------------------------------------------------------

variable "use_ubuntu_24" {
  description = "Use Ubuntu 24.04 LTS (recommended). Set to false for Ubuntu 22.04"
  type        = bool
  default     = true
}

variable "db_instance_type" {
  description = "EC2 instance type for Oracle XE DB server (minimum t3.medium)"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^(t3\\.(medium|large|xlarge|2xlarge)|t2\\.(medium|large|xlarge|2xlarge)|m5\\.|m6i\\.|r5\\.|r6i\\.)", var.db_instance_type))
    error_message = "Oracle XE requires at least t3.medium or equivalent. t2.micro/small are not supported."
  }
}

variable "db_volume_size" {
  description = "Root volume size in GB for Oracle XE DB server (minimum 20GB)"
  type        = number
  default     = 30

  validation {
    condition     = var.db_volume_size >= 20
    error_message = "Oracle XE requires at least 20GB root volume."
  }
}

variable "db_service" {
  description = "Oracle service name (default: XEPDB1 for Oracle XE pluggable database)"
  type        = string
  default     = "XEPDB1"
}

variable "db_user" {
  description = "Oracle database application username"
  type        = string
  default     = "appuser"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_user))
    error_message = "Oracle username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_password" {
  description = "Oracle database password (used for SYS and application user)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && can(regex("[A-Z]", var.db_password)) && can(regex("[a-z]", var.db_password)) && can(regex("[0-9]", var.db_password))
    error_message = "Oracle password must be at least 8 characters and include uppercase, lowercase, and numbers."
  }
}

variable "db_elastic_ip_allocation_id" {
  description = "Allocation ID of existing Elastic IP to associate with the DB instance"
  type        = string
}

#------------------------------------------------------------------------------
# AWS CLI Configuration (Optional - for Data Pump S3 integration)
#------------------------------------------------------------------------------

variable "aws_access_key_id" {
  description = "AWS Access Key ID for CLI on DB server (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for CLI on DB server (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for data pump exports"
  type        = string
  default     = "cfwdemobucket"
}
