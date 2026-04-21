mock_provider "aws" {
  alias = "mock"

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }
}

run "plan_defaults" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    availability_zone = "us-west-2a"
  }

  assert {
    condition     = aws_vpc.lab.cidr_block == "172.16.0.0/16"
    error_message = "The default VPC CIDR should match the design doc."
  }

  assert {
    condition     = aws_subnet.public.availability_zone == "us-west-2a"
    error_message = "The public subnet should use the requested availability zone."
  }

  assert {
    condition     = aws_route53_zone.private.name == "glab.lol"
    error_message = "The private hosted zone should default to glab.lol."
  }

  assert {
    condition     = aws_kms_alias.sops.name == "alias/glab-sops"
    error_message = "The SOPS KMS alias should match the expected default."
  }
}

run "plan_overrides" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    availability_zone = "us-west-2b"
    kms_alias         = "glab-bootstrap"
    private_zone_name = "corp.glab.lol"
  }

  assert {
    condition     = aws_subnet.public.availability_zone == "us-west-2b"
    error_message = "The public subnet should honor the overridden availability zone."
  }

  assert {
    condition     = aws_route53_zone.private.name == "corp.glab.lol"
    error_message = "The private hosted zone should honor the overridden zone name."
  }

  assert {
    condition     = aws_kms_alias.sops.name == "alias/glab-bootstrap"
    error_message = "The SOPS KMS alias should honor the overridden alias."
  }
}

run "reject_invalid_vpc_cidr" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [
    var.vpc_cidr,
  ]
}
