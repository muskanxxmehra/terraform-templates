################################################################################
# EC2 App Module Outputs
################################################################################

output "instance_id" {
  description = "Instance ID of the application server"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "Private IP address of the application server"
  value       = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Public IP address of the application server"
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS name of the application server"
  value       = aws_instance.app.public_dns
}

output "eip_public_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_eip ? aws_eip.app[0].public_ip : null
}

output "app_url" {
  description = "Application URL"
  value       = "http://${var.create_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}:${var.app_port}"
}

