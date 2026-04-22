resource "aws_cloudwatch_log_group" "broker" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(local.common_tags, {
    Name = "/aws/lambda/${var.function_name}"
  })
}

resource "aws_lambda_function" "broker" {
  architectures = ["arm64"]
  filename      = data.archive_file.placeholder.output_path
  function_name = var.function_name
  handler       = "bootstrap"
  memory_size   = var.function_memory_size
  role          = aws_iam_role.execution.arn
  runtime       = "provided.al2023"
  timeout       = var.function_timeout

  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      GITHUB_TOKEN_BROKER_CLIENT_ID_PARAM       = var.client_id_parameter_name
      GITHUB_TOKEN_BROKER_INSTALLATION_ID_PARAM = var.installation_id_parameter_name
      GITHUB_TOKEN_BROKER_LOG_LEVEL             = var.log_level
      GITHUB_TOKEN_BROKER_PRIVATE_KEY_PARAM     = var.private_key_parameter_name
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.broker,
    aws_iam_role_policy.execution_logs,
    aws_iam_role_policy.execution_ssm,
  ]

  tags = merge(local.common_tags, {
    Name = var.function_name
  })
}
