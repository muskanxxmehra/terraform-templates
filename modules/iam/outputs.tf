output "role_arn" {
  description = "IAM Role ARN"
  value       = aws_iam_role.ec2_role.arn
}

output "role_name" {
  description = "IAM Role Name"
  value       = aws_iam_role.ec2_role.name
}

output "instance_profile_name" {
  description = "IAM Instance Profile Name"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "instance_profile_arn" {
  description = "IAM Instance Profile ARN"
  value       = aws_iam_instance_profile.ec2_profile.arn
}
