output "dns_name" {
  description = "Private DNS name for the Keycloak service."
  value       = aws_route53_record.private.fqdn
}

output "iam_role_arn" {
  description = "IAM role ARN used by the Keycloak instance."
  value       = aws_iam_role.keycloak.arn
}

output "github_token_broker_function_arn" {
  description = "ARN of the GitHub token broker Lambda deployed for Keycloak bootstrap access."
  value       = module.github_token_broker.function_arn
}

output "github_token_broker_function_name" {
  description = "Name of the GitHub token broker Lambda deployed for Keycloak bootstrap access."
  value       = module.github_token_broker.function_name
}

output "github_token_broker_log_group_name" {
  description = "CloudWatch log group for the GitHub token broker Lambda."
  value       = module.github_token_broker.log_group_name
}

output "github_token_broker_release_version" {
  description = "GitHub token broker release version deployed by this stack."
  value       = module.github_token_broker.deployed_version
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

output "data_volume_id" {
  description = "Encrypted EBS volume ID mounted at /var/lib/keycloak."
  value       = aws_ebs_volume.keycloak_data.id
}

output "bootstrap_unit_name" {
  description = "Systemd unit that fetches Keycloak bootstrap secrets."
  value       = local.bootstrap_unit_name
}

output "service_unit_names" {
  description = "Systemd units that run the Flatcar Keycloak stack."
  value = {
    data     = local.data_unit_name
    network  = local.network_unit_name
    postgres = local.postgres_unit_name
    keycloak = local.keycloak_unit_name
    traefik  = local.traefik_unit_name
  }
}

output "acme_challenge_record_name" {
  description = "Route 53 TXT record name Traefik may mutate for Keycloak ACME DNS-01 validation."
  value       = local.acme_challenge_record_name
}

output "acme_zone_id" {
  description = "Public Route 53 hosted zone ID used for Keycloak ACME DNS-01 validation."
  value       = data.aws_route53_zone.acme.zone_id
}
