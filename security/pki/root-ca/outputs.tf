output "key_id" {
  description = "KMS key ID of the root CA."
  value       = aws_kms_key.root_ca.key_id
}

output "key_arn" {
  description = "KMS key ARN of the root CA."
  value       = aws_kms_key.root_ca.arn
}

output "key_alias" {
  description = "KMS alias name for the root CA key."
  value       = aws_kms_alias.root_ca.name
}

output "key_spec" {
  description = "Customer master key spec of the root CA key."
  value       = aws_kms_key.root_ca.customer_master_key_spec
}
