output "bootstrap_unit_name" {
  description = "Systemd unit that fetches the Keycloak bootstrap secret."
  value       = local.bootstrap_unit_name
}

output "github_token_broker_function_arn" {
  description = "ARN of the GitHub token broker Lambda invoked by the spike instance."
  value       = data.aws_lambda_function.github_token_broker.arn
}

output "iam_role_arn" {
  description = "IAM role ARN used by the Flatcar spike instance."
  value       = aws_iam_role.flatcar.arn
}

output "instance_id" {
  description = "EC2 instance ID of the Flatcar spike host."
  value       = aws_instance.flatcar.id
}

output "private_ip" {
  description = "Private IPv4 address of the Flatcar spike host."
  value       = aws_instance.flatcar.private_ip
}

output "public_ip" {
  description = "Public IPv4 address associated with the Flatcar spike host for outbound bootstrap traffic."
  value       = aws_instance.flatcar.public_ip
}

output "security_group_id" {
  description = "Security group attached to the Flatcar spike host."
  value       = aws_security_group.flatcar.id
}
