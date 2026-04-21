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

output "acme_challenge_record_name" {
  description = "Route 53 TXT record name Traefik may mutate for Keycloak ACME DNS-01 validation."
  value       = local.acme_challenge_record_name
}

output "acme_zone_id" {
  description = "Public Route 53 hosted zone ID used for Keycloak ACME DNS-01 validation."
  value       = data.aws_route53_zone.acme.zone_id
}

output "ssm_parameter_names" {
  description = "SSM Parameter Store names where the host stores generated bootstrap credentials."
  value       = local.ssm_parameter_names
}
