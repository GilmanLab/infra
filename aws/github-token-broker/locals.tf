locals {
  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "github-token-broker"
  })

  ssm_parameter_names = {
    client_id       = var.client_id_parameter_name
    installation_id = var.installation_id_parameter_name
    private_key     = var.private_key_parameter_name
  }

  ssm_parameter_arns = {
    for key, name in local.ssm_parameter_names :
    key => "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${name}"
  }

  github_oidc_host         = replace(var.github_oidc_provider_url, "https://", "")
  github_oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github_actions[0].arn

  lambda_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  lambda_logs_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWriteTokenBrokerLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.broker.arn}:*"
      },
    ]
  })

  lambda_ssm_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadGitHubAppParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = values(local.ssm_parameter_arns)
      },
    ]
  })

  lambda_private_key_kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDecryptGitHubAppPrivateKeyParameter"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = var.private_key_kms_key_arn
      },
    ]
  })

  publisher_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.github_oidc_host}:aud" = var.github_oidc_audience
          }
          StringLike = {
            "${local.github_oidc_host}:sub" = var.github_oidc_subject
          }
        }
      },
    ]
  })

  publisher_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublishGitHubTokenBrokerCode"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:UpdateFunctionCode",
        ]
        Resource = aws_lambda_function.broker.arn
      },
    ]
  })

  invoke_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowInvokeGitHubTokenBroker"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
        ]
        Resource = [
          aws_lambda_function.broker.arn,
          "${aws_lambda_function.broker.arn}:*",
        ]
      },
    ]
  })
}
