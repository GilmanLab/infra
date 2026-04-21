output "execution_role_arn" {
  description = "IAM role ARN used by the GitHub token broker Lambda."
  value       = aws_iam_role.execution.arn
}

output "function_arn" {
  description = "ARN of the GitHub token broker Lambda function."
  value       = aws_lambda_function.broker.arn
}

output "function_name" {
  description = "Name of the GitHub token broker Lambda function."
  value       = aws_lambda_function.broker.function_name
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN used by the publisher role."
  value       = local.github_oidc_provider_arn
}

output "invoke_policy_arn" {
  description = "IAM policy ARN that can be attached to bootstrap principals allowed to invoke the broker."
  value       = aws_iam_policy.invoke.arn
}

output "publisher_role_arn" {
  description = "IAM role ARN assumed by the platform release workflow to publish Lambda code."
  value       = aws_iam_role.publisher.arn
}

output "ssm_parameter_names" {
  description = "SSM parameter names read by the GitHub token broker Lambda."
  value       = local.ssm_parameter_names
}
