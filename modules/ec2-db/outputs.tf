################################################################################
# EC2 DB Module Outputs - Oracle XE via Docker
################################################################################

# To get the EIP public IP, we need to use a data source
data "aws_eip" "db" {
  id = var.elastic_ip_allocation_id
}

output "instance_id" {
  description = "Instance ID of the Oracle XE database server"
  value       = aws_instance.db.id
}

output "private_ip" {
  description = "Private IP address of the database server"
  value       = aws_instance.db.private_ip
}

output "public_ip" {
  description = "Public IP address of the database server (Elastic IP)"
  value       = data.aws_eip.db.public_ip
}

output "public_dns" {
  description = "Public DNS name of the database server (Elastic IP)"
  value       = data.aws_eip.db.public_dns
}

output "elastic_ip_association_id" {
  description = "EIP association ID"
  value       = aws_eip_association.db.id
}

output "connection_string" {
  description = "Oracle connection string"
  value       = "${var.db_user}@${aws_instance.db.private_ip}:1521/XEPDB1"
}

output "jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:oracle:thin:@${aws_instance.db.private_ip}:1521/XEPDB1"
}

output "connection_string_public" {
  description = "Oracle connection string (using public EIP)"
  value       = "${var.db_user}@${data.aws_eip.db.public_ip}:1521/XEPDB1"
}

output "jdbc_url_public" {
  description = "JDBC connection URL (using public EIP)"
  value       = "jdbc:oracle:thin:@${data.aws_eip.db.public_ip}:1521/XEPDB1"
}
