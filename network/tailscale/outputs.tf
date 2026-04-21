output "aws_subnet_router_audience" {
  description = "Audience that the AWS subnet router must request when exchanging its AWS-issued OIDC token with Tailscale."
  value       = tailscale_federated_identity.aws_subnet_router.audience
}

output "aws_subnet_router_client_id" {
  description = "Client ID that the AWS subnet router passes to tailscale up when using workload identity federation."
  value       = tailscale_federated_identity.aws_subnet_router.id
}
