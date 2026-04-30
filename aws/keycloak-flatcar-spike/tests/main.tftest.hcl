mock_provider "aws" {
  alias = "mock"

  mock_data "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-west-2:123456789012:function:glab-github-token-broker"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
      id  = "mock-role"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      id = "subnet-00000000"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-00000000"
    }
  }
}

run "plan_defaults" {
  command = plan

  providers = {
    aws = aws.mock
  }

  assert {
    condition     = aws_instance.flatcar.ami == "ami-0ce605082061bbb10"
    error_message = "The spike should default to the current Flatcar stable arm64 AMI for us-west-2."
  }

  assert {
    condition     = aws_instance.flatcar.instance_type == "t4g.small"
    error_message = "The spike should default to the small Graviton instance class."
  }

  assert {
    condition     = aws_instance.flatcar.metadata_options[0].http_tokens == "required"
    error_message = "The Flatcar host should require IMDSv2."
  }

  assert {
    condition     = aws_instance.flatcar.metadata_options[0].http_put_response_hop_limit == 2
    error_message = "The Flatcar host should allow containerized labctl to reach IMDSv2."
  }

  assert {
    condition     = aws_instance.flatcar.root_block_device[0].encrypted == true && aws_instance.flatcar.root_block_device[0].volume_type == "gp3" && aws_instance.flatcar.root_block_device[0].volume_size == 16
    error_message = "The spike root volume should be an encrypted 16 GiB gp3 volume matching the Flatcar AMI mapping."
  }

  assert {
    condition     = strcontains(local.ignition_config, "\"version\":\"3.3.0\"")
    error_message = "The spike should pass raw Ignition v3 JSON as EC2 user data."
  }

  assert {
    condition     = strcontains(local.ignition_config, "amazon-ssm-agent.service")
    error_message = "The spike should enable the Flatcar AWS SSM agent."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "ghcr.io/gilmanlab/platform/labctl@sha256:4638b36a168df88d4206d5ff23aed62a6d8459ba7a2481c0b7c65c696445c1ec")
    error_message = "The bootstrap unit should use the pinned labctl 0.2.0 image digest."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "--user 0:0")
    error_message = "The bootstrap container should run as root so it can write into the root-owned 0700 /run directory."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "secrets get services/keycloak/bootstrap.sops.yaml --source github --field /stack_env --output /run/glab/keycloak/stack.env")
    error_message = "The bootstrap unit should fetch only the Keycloak stack_env field into /run."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "--aws-region us-west-2 --broker-function glab-github-token-broker")
    error_message = "The bootstrap unit should call the live broker in us-west-2."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.github_token_broker_invoke.policy, "lambda:InvokeFunction") && strcontains(aws_iam_role_policy.github_token_broker_invoke.policy, "arn:aws:lambda:us-west-2:123456789012:function:glab-github-token-broker")
    error_message = "The instance role should be able to invoke only the configured token broker."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.sops_keycloak_decrypt.policy, "kms:Decrypt") && strcontains(aws_iam_role_policy.sops_keycloak_decrypt.policy, "kms:EncryptionContext:Repo") && strcontains(aws_iam_role_policy.sops_keycloak_decrypt.policy, "GilmanLab/secrets") && strcontains(aws_iam_role_policy.sops_keycloak_decrypt.policy, "kms:EncryptionContext:Scope") && strcontains(aws_iam_role_policy.sops_keycloak_decrypt.policy, "keycloak")
    error_message = "The KMS decrypt grant should be constrained to the Keycloak SOPS encryption context."
  }
}

run "plan_overrides" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    flatcar_ami_id                    = "ami-00000000000000000"
    github_token_broker_function_name = "glab-keycloak-staging-github-token-broker"
    instance_name                     = "glab-aws-keycloak-flatcar-staging"
    instance_type                     = "t4g.medium"
  }

  assert {
    condition     = aws_instance.flatcar.ami == "ami-00000000000000000"
    error_message = "The Flatcar AMI override should propagate."
  }

  assert {
    condition     = aws_instance.flatcar.instance_type == "t4g.medium"
    error_message = "The instance type override should propagate."
  }

  assert {
    condition     = aws_instance.flatcar.tags["Name"] == "glab-aws-keycloak-flatcar-staging"
    error_message = "The instance Name tag should honor the instance_name override."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "--broker-function glab-keycloak-staging-github-token-broker")
    error_message = "The broker function override should propagate into the bootstrap unit."
  }
}

run "reject_unpinned_labctl_image" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    labctl_image = "ghcr.io/gilmanlab/platform/labctl:0.2.0"
  }

  expect_failures = [
    var.labctl_image,
  ]
}

run "reject_persistent_bootstrap_output_path" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    bootstrap_output_path = "/etc/keycloak/stack.env"
  }

  expect_failures = [
    var.bootstrap_output_path,
  ]
}

run "reject_non_keycloak_secret_path" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    bootstrap_secret_path = "network/vyos/bootstrap.sops.yaml"
  }

  expect_failures = [
    var.bootstrap_secret_path,
  ]
}

run "reject_root_volume_growth" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    root_volume_size = 12
  }

  expect_failures = [
    var.root_volume_size,
  ]
}
