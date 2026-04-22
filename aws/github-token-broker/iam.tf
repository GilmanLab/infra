resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.github_oidc_provider_arn == "" ? 1 : 0

  client_id_list = [
    var.github_oidc_audience,
  ]
  url = var.github_oidc_provider_url

  tags = merge(local.common_tags, {
    Name = "github-actions"
  })
}

resource "aws_iam_role" "execution" {
  assume_role_policy = local.lambda_assume_role_policy
  name               = var.execution_role_name

  tags = merge(local.common_tags, {
    Name = var.execution_role_name
  })
}

resource "aws_iam_role_policy" "execution_logs" {
  name   = "${var.execution_role_name}-logs"
  policy = local.lambda_logs_policy
  role   = aws_iam_role.execution.id
}

resource "aws_iam_role_policy" "execution_ssm" {
  name   = "${var.execution_role_name}-ssm"
  policy = local.lambda_ssm_policy
  role   = aws_iam_role.execution.id
}

resource "aws_iam_role_policy" "execution_private_key_kms" {
  count = var.private_key_kms_key_arn == "" ? 0 : 1

  name   = "${var.execution_role_name}-private-key-kms"
  policy = local.lambda_private_key_kms_policy
  role   = aws_iam_role.execution.id
}

resource "aws_iam_role" "publisher" {
  assume_role_policy = local.publisher_assume_role_policy
  name               = var.publisher_role_name

  tags = merge(local.common_tags, {
    Name = var.publisher_role_name
  })
}

resource "aws_iam_role_policy" "publisher" {
  name   = "${var.publisher_role_name}-lambda-code"
  policy = local.publisher_policy
  role   = aws_iam_role.publisher.id
}

resource "aws_iam_policy" "invoke" {
  description = "Allows bootstrap principals to invoke the GitHub token broker Lambda."
  name        = "${var.function_name}-invoke"
  policy      = local.invoke_policy

  tags = merge(local.common_tags, {
    Name = "${var.function_name}-invoke"
  })
}
