################################################################################
# EC2 DB Module Outputs - Oracle XE via Docker
################################################################################

output "instance_id" {
  description = "Instance ID of the Oracle XE database server"
  value       = aws_instance.db.id
}

output "private_ip" {
  description = "Private IP address of the database server"
  value       = aws_instance.db.private_ip
}

output "public_ip" {
  description = "Public IP address of the database server"
  value       = aws_instance.db.public_ip
}

output "public_dns" {
  description = "Public DNS name of the database server"
  value       = aws_instance.db.public_dns
}

output "connection_string" {
  description = "Oracle connection string"
  value       = "${var.db_user}@${aws_instance.db.private_ip}:1521/XEPDB1"
}

output "jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:oracle:thin:@${aws_instance.db.private_ip}:1521/XEPDB1"
}

