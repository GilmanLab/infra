mock_provider "aws" {
  alias = "mock"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
      id  = "mock-role"
    }
  }

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z00000000000000000"
    }
  }

  mock_data "aws_route_table" {
    defaults = {
      id = "rtb-00000000"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0000000000000000"
    }
  }

  mock_data "aws_instance" {
    defaults = {
      id = "i-0000000000000000"
    }
  }

  mock_data "aws_network_interface" {
    defaults = {
      id = "eni-00000000000000000"
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
    condition     = aws_instance.keycloak.instance_type == "t4g.small"
    error_message = "The default instance type should match the design doc."
  }

  assert {
    condition     = aws_instance.keycloak.associate_public_ip_address == true
    error_message = "The Keycloak host should have a public IPv4 address for outbound bootstrap traffic."
  }

  assert {
    condition     = aws_instance.keycloak.metadata_options[0].http_tokens == "required"
    error_message = "The Keycloak host should require IMDSv2."
  }

  assert {
    condition     = aws_instance.keycloak.root_block_device[0].encrypted == true
    error_message = "The Keycloak root volume should be encrypted."
  }

  assert {
    condition     = aws_route53_record.private.name == "id.glab.lol"
    error_message = "The private DNS record should default to id.glab.lol."
  }

  assert {
    condition     = local.acme_challenge_record_name == "_acme-challenge.id.acme.glab.lol"
    error_message = "The default ACME challenge record should target the delegated Route 53 zone."
  }

  assert {
    condition     = strcontains(local.compose, "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=route53")
    error_message = "Traefik should use the Route 53 DNS-01 provider."
  }

  assert {
    condition     = strcontains(local.compose, "AWS_HOSTED_ZONE_ID: Z00000000000000000")
    error_message = "Traefik should receive the delegated Route 53 zone ID."
  }

  assert {
    condition     = strcontains(local.traefik_dynamic_config, "certResolver: letsencrypt")
    error_message = "The Keycloak router should request certificates through the Let's Encrypt resolver."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.keycloak_https) == 1
    error_message = "The default lab CIDRs should produce exactly one HTTPS ingress rule."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.operator_tailscale_https) == 2
    error_message = "The root module's operator_tailscale_cidrs should produce two HTTPS ingress rules."
  }

  assert {
    condition     = alltrue([for rule in aws_vpc_security_group_ingress_rule.keycloak_https : rule.cidr_ipv4 != "0.0.0.0/0" && rule.from_port == 443 && rule.to_port == 443 && rule.ip_protocol == "tcp"])
    error_message = "Keycloak ingress should expose only HTTPS to non-public lab CIDRs."
  }

  assert {
    condition     = module.github_token_broker.function_name == "glab-github-token-broker"
    error_message = "The Keycloak stack should deploy the shared GitHub token broker name."
  }

  assert {
    condition     = module.github_token_broker.deployed_version == "v1.1.0"
    error_message = "The Keycloak stack should pin the current broker release."
  }

  assert {
    condition     = aws_iam_role_policy.keycloak_github_token_broker_invoke.role == aws_iam_role.keycloak.id
    error_message = "The Keycloak instance role should be allowed to invoke the token broker."
  }
}

run "plan_overrides" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    instance_name                     = "glab-aws-keycloak-staging"
    instance_type                     = "t4g.medium"
    github_token_broker_function_name = "glab-keycloak-staging-github-token-broker"
    lab_cidrs                         = ["10.10.0.0/16", "10.20.0.0/16"]
    operator_tailscale_cidrs = {
      laptop = "100.64.1.1/32"
      studio = "100.64.1.2/32"
    }
    private_hostname = "id.staging.glab.lol"
  }

  assert {
    condition     = aws_instance.keycloak.instance_type == "t4g.medium"
    error_message = "The instance type override should propagate."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.keycloak_https) == 2
    error_message = "Two lab CIDRs should produce two HTTPS ingress rules."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.operator_tailscale_https) == 2
    error_message = "Two operator Tailscale CIDRs should produce two HTTPS ingress rules."
  }

  assert {
    condition     = length(aws_route.operator_tailscale) == 2
    error_message = "Two operator Tailscale CIDRs should produce two return routes through the subnet router."
  }

  assert {
    condition     = aws_instance.keycloak.tags["Name"] == "glab-aws-keycloak-staging"
    error_message = "The instance Name tag should honor the instance_name override."
  }

  assert {
    condition     = aws_route53_record.private.name == "id.staging.glab.lol"
    error_message = "The private hostname override should propagate to DNS."
  }

  assert {
    condition     = local.acme_challenge_record_name == "_acme-challenge.id.staging.acme.glab.lol"
    error_message = "The delegated ACME challenge record should follow the private hostname override."
  }

  assert {
    condition     = module.github_token_broker.function_name == "glab-keycloak-staging-github-token-broker"
    error_message = "The broker function name override should propagate."
  }
}

run "reject_invalid_lab_cidr" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    lab_cidrs = ["not-a-cidr"]
  }

  expect_failures = [
    var.lab_cidrs,
  ]
}

run "reject_invalid_operator_tailscale_cidr" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    operator_tailscale_cidrs = {
      laptop = "not-a-cidr"
    }
  }

  expect_failures = [
    var.operator_tailscale_cidrs,
  ]
}

run "reject_invalid_root_volume_size" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    root_volume_size = 4
  }

  expect_failures = [
    var.root_volume_size,
  ]
}

run "reject_invalid_ssm_parameter_prefix" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    ssm_parameter_prefix = "glab/keycloak/"
  }

  expect_failures = [
    var.ssm_parameter_prefix,
  ]
}
