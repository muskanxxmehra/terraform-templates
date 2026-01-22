################################################################################
# AWS App + Oracle XE DB Service (Docker) - Outputs
################################################################################

#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.public_subnet_id
}

#------------------------------------------------------------------------------
# Database Server Outputs
#------------------------------------------------------------------------------

output "db_instance_id" {
  description = "Database server instance ID"
  value       = module.db.instance_id
}

output "db_private_ip" {
  description = "Database server private IP"
  value       = module.db.private_ip
}

output "db_public_ip" {
  description = "Database server public IP"
  value       = module.db.public_ip
}

output "db_public_dns" {
  description = "Database server public DNS"
  value       = module.db.public_dns
}

output "oracle_connection_string" {
  description = "Oracle connection string"
  value       = module.db.connection_string
}

output "oracle_jdbc_url" {
  description = "Oracle JDBC URL"
  value       = module.db.jdbc_url
}

#------------------------------------------------------------------------------
# Application Server Outputs
#------------------------------------------------------------------------------

output "app_instance_id" {
  description = "Application server instance ID"
  value       = module.app.instance_id
}

output "app_private_ip" {
  description = "Application server private IP"
  value       = module.app.private_ip
}

output "app_public_ip" {
  description = "Application server public IP"
  value       = module.app.public_ip
}

output "app_public_dns" {
  description = "Application server public DNS"
  value       = module.app.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = module.app.app_url
}

#------------------------------------------------------------------------------
# Connection Information
#------------------------------------------------------------------------------

output "ssh_command_db" {
  description = "SSH command to connect to database server"
  value       = "ssh -i <your-key.pem> ubuntu@${module.db.public_ip}"
}

output "ssh_command_app" {
  description = "SSH command to connect to application server"
  value       = "ssh -i <your-key.pem> ubuntu@${module.app.public_ip}"
}

output "docker_logs_command" {
  description = "Command to view Oracle XE Docker logs"
  value       = "ssh -i <your-key.pem> ubuntu@${module.db.public_ip} 'docker logs -f oracle-xe'"
}

output "oracle_sqlplus_command" {
  description = "Command to connect via sqlplus"
  value       = "docker exec -it oracle-xe bash -lc 'sqlplus ${var.db_user}/${var.db_password}@XEPDB1'"
  sensitive   = true
}

