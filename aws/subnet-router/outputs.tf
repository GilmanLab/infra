output "instance_id" {
  description = "EC2 instance ID of the AWS subnet router."
  value       = aws_instance.subnet_router.id
}

output "instance_private_ip" {
  description = "Private IPv4 address of the AWS subnet router."
  value       = aws_instance.subnet_router.private_ip
}

output "instance_role_arn" {
  description = "IAM role ARN used by the AWS subnet router. This is the subject matched by the Tailscale federated identity."
  value       = aws_iam_role.subnet_router.arn
}

output "network_interface_id" {
  description = "Primary network interface ID of the AWS subnet router."
  value       = aws_instance.subnet_router.primary_network_interface_id
}

output "public_ip" {
  description = "Elastic IP attached to the AWS subnet router."
  value       = aws_eip.subnet_router.public_ip
}

output "security_group_id" {
  description = "Security group attached to the AWS subnet router."
  value       = aws_security_group.subnet_router.id
}
