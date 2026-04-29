module "github_token_broker" {
  # Pin the module to the provider-v5 compatibility fix until the next
  # meigma/github-token-broker release can carry it as a tag.
  source = "github.com/meigma/github-token-broker//terraform?ref=9fd93c65d9f7f8a72c51131084eba194d3575709"

  function_name    = var.github_token_broker_function_name
  repository_owner = "GilmanLab"
  repository_name  = "secrets"

  release_repository = var.github_token_broker_release_repository
  lambda_artifact = {
    release_version = var.github_token_broker_release_version
  }

  ssm_parameter_paths = var.github_token_broker_ssm_parameter_paths
  kms_key_arn         = var.github_token_broker_private_key_kms_key_arn
  permissions         = var.github_token_broker_permissions
  log_retention_days  = var.github_token_broker_log_retention_days

  tags = merge(local.common_tags, {
    "glab:purpose" = "keycloak-github-token-broker"
  })
}

data "aws_iam_policy_document" "keycloak_github_token_broker_invoke" {
  statement {
    sid = "AllowInvokeGitHubTokenBroker"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      module.github_token_broker.function_arn,
    ]
  }
}

resource "aws_iam_role_policy" "keycloak_github_token_broker_invoke" {
  name   = "${var.iam_role_name}-github-token-broker-invoke"
  policy = data.aws_iam_policy_document.keycloak_github_token_broker_invoke.json
  role   = aws_iam_role.keycloak.id
}
