mock_provider "aws" {
  alias = "mock"

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_ebs_volume" {
    defaults = {
      id = "vol-0123456789abcdef0"
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
      arn     = "arn:aws:route53:::hostedzone/Z00000000000000000"
      zone_id = "Z00000000000000000"
    }
  }

  mock_data "aws_route_table" {
    defaults = {
      id = "rtb-00000000"
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
      availability_zone = "us-west-2a"
      id                = "subnet-00000000"
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
    condition     = aws_instance.keycloak.ami == "ami-0ce605082061bbb10"
    error_message = "The Keycloak host should default to the current Flatcar stable arm64 AMI for us-west-2."
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
    condition     = aws_instance.keycloak.metadata_options[0].http_put_response_hop_limit == 2
    error_message = "The Keycloak host should allow containerized labctl to reach IMDSv2."
  }

  assert {
    condition     = aws_instance.keycloak.root_block_device[0].encrypted == true && aws_instance.keycloak.root_block_device[0].volume_type == "gp3" && aws_instance.keycloak.root_block_device[0].volume_size == 16
    error_message = "The Keycloak root volume should be an encrypted 16 GiB gp3 volume."
  }

  assert {
    condition     = aws_ebs_volume.keycloak_data.encrypted == true && aws_ebs_volume.keycloak_data.type == "gp3" && aws_ebs_volume.keycloak_data.size == 8
    error_message = "The Keycloak data volume should default to encrypted 8 GiB gp3."
  }

  assert {
    condition     = aws_volume_attachment.keycloak_data.device_name == "/dev/xvdf" && aws_volume_attachment.keycloak_data.volume_id == aws_ebs_volume.keycloak_data.id
    error_message = "The Keycloak data volume should attach to the Flatcar host."
  }

  assert {
    condition     = strcontains(local.ignition_config, "\"version\":\"3.3.0\"")
    error_message = "The Keycloak host should pass raw Ignition v3 JSON as EC2 user data."
  }

  assert {
    condition     = strcontains(local.ignition_config, "amazon-ssm-agent.service")
    error_message = "The Keycloak host should enable the Flatcar AWS SSM agent."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "ghcr.io/gilmanlab/platform/labctl@sha256:4638b36a168df88d4206d5ff23aed62a6d8459ba7a2481c0b7c65c696445c1ec")
    error_message = "The bootstrap unit should use the pinned labctl 0.2.0 image digest."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "--network host --user 0:0")
    error_message = "The bootstrap container should run with host networking and root inside the container."
  }

  assert {
    condition     = strcontains(local.bootstrap_unit, "secrets get services/keycloak/bootstrap.sops.yaml --source github --field /stack_env --output /run/glab/keycloak/stack.env")
    error_message = "The bootstrap unit should fetch only the Keycloak stack_env field into /run."
  }

  assert {
    condition     = strcontains(local.prepare_data_script, "/var/lib/keycloak/postgres") && strcontains(local.prepare_data_script, "/var/lib/keycloak/acme") && strcontains(local.prepare_data_script, "chown 999:999")
    error_message = "The data preparation script should place Postgres and ACME state on the data volume."
  }

  assert {
    condition     = strcontains(local.ignition_config, "/etc/glab/keycloak/bin/run-keycloak.sh") && !strcontains(local.ignition_config, "/usr/local/lib/glab-keycloak")
    error_message = "Ignition should write helper scripts under writable root-backed config paths, not Flatcar's read-only /usr tree."
  }

  assert {
    condition     = strcontains(local.run_keycloak_script, "/run/glab/keycloak/keycloak.env") && strcontains(local.run_keycloak_script, "KC_DB_PASSWORD")
    error_message = "The Keycloak runner should derive container-only env from the /run bootstrap secret."
  }

  assert {
    condition     = strcontains(local.run_traefik_script, "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=route53")
    error_message = "Traefik should use the Route 53 DNS-01 provider."
  }

  assert {
    condition     = strcontains(local.run_traefik_script, "AWS_HOSTED_ZONE_ID='Z00000000000000000'")
    error_message = "Traefik should receive the delegated Route 53 zone ID."
  }

  assert {
    condition     = strcontains(local.traefik_dynamic_config, "certResolver: letsencrypt")
    error_message = "The Keycloak router should request certificates through the Let's Encrypt resolver."
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
    condition     = module.github_token_broker.deployed_version == "v2.0.0"
    error_message = "The Keycloak stack should pin the current broker release."
  }

  assert {
    condition     = aws_iam_role_policy.keycloak_github_token_broker_invoke.role == aws_iam_role.keycloak.id
    error_message = "The Keycloak instance role should be allowed to invoke the token broker."
  }

  assert {
    condition     = aws_iam_role_policy.keycloak_sops_decrypt.role == aws_iam_role.keycloak.id
    error_message = "The Keycloak instance role should receive the SOPS KMS decrypt policy."
  }
}

run "plan_overrides" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    data_volume_size                  = 32
    flatcar_ami_id                    = "ami-00000000000000000"
    github_token_broker_function_name = "glab-keycloak-staging-github-token-broker"
    instance_name                     = "glab-aws-keycloak-staging"
    instance_type                     = "t4g.medium"
    lab_cidrs                         = ["10.10.0.0/16", "10.20.0.0/16"]
    operator_tailscale_cidrs = {
      laptop = "100.64.1.1/32"
      studio = "100.64.1.2/32"
    }
    private_hostname = "id.staging.glab.lol"
  }

  assert {
    condition     = aws_instance.keycloak.ami == "ami-00000000000000000"
    error_message = "The Flatcar AMI override should propagate."
  }

  assert {
    condition     = aws_instance.keycloak.instance_type == "t4g.medium"
    error_message = "The instance type override should propagate."
  }

  assert {
    condition     = aws_ebs_volume.keycloak_data.size == 32
    error_message = "The data volume size override should propagate."
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
    root_volume_size = 12
  }

  expect_failures = [
    var.root_volume_size,
  ]
}

run "reject_invalid_data_volume_size" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    data_volume_size = 4
  }

  expect_failures = [
    var.data_volume_size,
  ]
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
