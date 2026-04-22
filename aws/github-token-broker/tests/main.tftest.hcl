mock_provider "aws" {
  alias = "mock"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-west-2:123456789012:function:glab-github-token-broker"
    }
  }
}

run "plan_defaults" {
  command = plan

  providers = {
    aws = aws.mock
  }

  assert {
    condition     = aws_lambda_function.broker.function_name == "glab-github-token-broker"
    error_message = "The Lambda function name should match the platform publish workflow."
  }

  assert {
    condition     = aws_lambda_function.broker.runtime == "provided.al2023"
    error_message = "The Lambda should use the Amazon Linux 2023 custom runtime."
  }

  assert {
    condition     = aws_lambda_function.broker.architectures[0] == "arm64"
    error_message = "The Lambda should default to arm64."
  }

  assert {
    condition     = aws_lambda_function.broker.environment[0].variables.GITHUB_TOKEN_BROKER_PRIVATE_KEY_PARAM == "/glab/bootstrap/github-app/private-key-pem"
    error_message = "The Lambda should read the expected private-key SSM parameter."
  }

  assert {
    condition     = aws_cloudwatch_log_group.broker.retention_in_days == 30
    error_message = "The Lambda log group should default to 30 day retention."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions[0].url == "https://token.actions.githubusercontent.com"
    error_message = "The default stack should create a GitHub Actions OIDC provider."
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github_actions[0].client_id_list, "sts.amazonaws.com")
    error_message = "The GitHub Actions OIDC provider should trust the AWS STS audience."
  }

  assert {
    condition     = jsondecode(aws_iam_role.publisher.assume_role_policy).Statement[0].Condition.StringLike["token.actions.githubusercontent.com:sub"] == "repo:GilmanLab/platform:ref:refs/tags/github-token-broker-v*"
    error_message = "The publisher role should be scoped to github-token-broker release tags."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.publisher.policy).Statement[0].Action, "lambda:UpdateFunctionCode")
    error_message = "The publisher role should be able to update Lambda function code."
  }

  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.publisher.policy).Statement[0].Action, "lambda:InvokeFunction")
    error_message = "The publisher role should not be able to invoke the broker."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.execution_ssm.policy).Statement[0].Resource, "arn:aws:ssm:us-west-2:123456789012:parameter/glab/bootstrap/github-app/private-key-pem")
    error_message = "The execution role should be scoped to the GitHub App SSM parameters."
  }
}

run "plan_existing_oidc_provider" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github_actions) == 0
    error_message = "The stack should not create a duplicate OIDC provider when an ARN is supplied."
  }

  assert {
    condition     = jsondecode(aws_iam_role.publisher.assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "The publisher role should trust the supplied OIDC provider ARN."
  }
}

run "plan_private_key_cmk" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    private_key_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_iam_role_policy.execution_private_key_kms) == 1
    error_message = "Supplying a private-key CMK should add a KMS decrypt policy."
  }
}

run "reject_relative_private_key_parameter" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    private_key_parameter_name = "glab/bootstrap/github-app/private-key-pem"
  }

  expect_failures = [
    var.private_key_parameter_name,
  ]
}

run "reject_wrong_github_subject_repo" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    github_oidc_subject = "repo:OtherOrg/platform:ref:refs/tags/github-token-broker-v*"
  }

  expect_failures = [
    var.github_oidc_subject,
  ]
}
