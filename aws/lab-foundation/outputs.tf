output "account_id" {
  description = "AWS account ID where the lab foundation stack is applied."
  value       = data.aws_caller_identity.current.account_id
}

output "availability_zone" {
  description = "Availability zone selected for the public subnet."
  value       = local.selected_availability_zone
}

output "vpc_id" {
  description = "VPC ID for the lab foundation network."
  value       = aws_vpc.lab.id
}

output "public_subnet_id" {
  description = "Subnet ID of the single public subnet."
  value       = aws_subnet.public.id
}

output "public_route_table_id" {
  description = "Route table ID attached to the public subnet."
  value       = aws_route_table.public.id
}

output "private_zone_id" {
  description = "Route 53 hosted zone ID for the private lab zone."
  value       = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Route 53 hosted zone name for the private lab zone."
  value       = aws_route53_zone.private.name
}

output "acme_zone_id" {
  description = "Route 53 hosted zone ID for the public ACME validation zone."
  value       = aws_route53_zone.acme.zone_id
}

output "acme_zone_name" {
  description = "Route 53 hosted zone name for the public ACME validation zone."
  value       = aws_route53_zone.acme.name
}

output "acme_zone_name_servers" {
  description = "Nameservers to delegate from Cloudflare for the public ACME validation zone."
  value       = aws_route53_zone.acme.name_servers
}

output "sops_kms_key_id" {
  description = "KMS key ID for the SOPS recipient key."
  value       = aws_kms_key.sops.key_id
}

output "sops_kms_key_arn" {
  description = "KMS key ARN for the SOPS recipient key."
  value       = aws_kms_key.sops.arn
}

output "sops_kms_alias" {
  description = "KMS alias name for the SOPS recipient key."
  value       = aws_kms_alias.sops.name
}
