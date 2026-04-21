mock_provider "aws" {
  alias = "mock"

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0000000000000000"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-00000000"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      id = "subnet-00000000"
    }
  }

  mock_data "aws_route_table" {
    defaults = {
      id = "rtb-00000000"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  dns_mirror_image    = "ghcr.io/gilmanlab/platform/services/dns-mirror:0.0.0-test"
  tailscale_audience  = "api.tailscale.com/test-audience"
  tailscale_client_id = "test-client-id"
}

run "plan_defaults" {
  command = plan

  providers = {
    aws = aws.mock
  }

  assert {
    condition     = aws_instance.subnet_router.instance_type == "t4g.nano"
    error_message = "The default instance type should match the design doc."
  }

  assert {
    condition     = aws_iam_role.subnet_router.name == "glab-aws-subnet-router"
    error_message = "The IAM role should default to glab-aws-subnet-router."
  }

  assert {
    condition     = length(aws_route.lab) == 1
    error_message = "The default lab_cidrs should produce exactly one route."
  }

  assert {
    condition     = local.tailscale_advertise_routes_csv == "172.16.0.0/16"
    error_message = "The default advertised routes should produce the AWS VPC CIDR."
  }
}

run "plan_overrides" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    instance_name = "glab-aws-subnet-router-staging"
    instance_type = "t4g.small"
    lab_cidrs     = ["10.10.0.0/16", "10.20.0.0/16"]
  }

  assert {
    condition     = aws_instance.subnet_router.instance_type == "t4g.small"
    error_message = "The instance type override should propagate."
  }

  assert {
    condition     = length(aws_route.lab) == 2
    error_message = "Two lab CIDRs should produce two routes."
  }

  assert {
    condition     = aws_instance.subnet_router.tags["Name"] == "glab-aws-subnet-router-staging"
    error_message = "The instance Name tag should honor the instance_name override."
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

run "reject_invalid_tailscale_tag" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    tailscale_tag = "subnet-router"
  }

  expect_failures = [
    var.tailscale_tag,
  ]
}
