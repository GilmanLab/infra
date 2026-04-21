output "dns_name" {
  description = "Private DNS name for the Keycloak service."
  value       = aws_route53_record.private.fqdn
}

output "iam_role_arn" {
  description = "IAM role ARN used by the Keycloak instance."
  value       = aws_iam_role.keycloak.arn
}

output "instance_id" {
  description = "EC2 instance ID of the Keycloak host."
  value       = aws_instance.keycloak.id
}

output "private_ip" {
  description = "Private IPv4 address of the Keycloak host."
  value       = aws_instance.keycloak.private_ip
}

output "public_ip" {
  description = "Public IPv4 address associated with the Keycloak host for outbound bootstrap traffic."
  value       = aws_instance.keycloak.public_ip
}

output "security_group_id" {
  description = "Security group attached to the Keycloak host."
  value       = aws_security_group.keycloak.id
}

output "ssm_parameter_names" {
  description = "SSM Parameter Store names where the host stores generated bootstrap credentials."
  value       = local.ssm_parameter_names
}
