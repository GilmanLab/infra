data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "keycloak_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "keycloak_bootstrap_parameters" {
  statement {
    sid = "AllowReadWriteKeycloakBootstrapParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = [
      local.ssm_parameter_path_arn,
    ]
  }
}

data "aws_route53_zone" "private" {
  name         = var.private_zone_name
  private_zone = true
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = var.ami_ssm_parameter_name
}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = [var.public_subnet_name]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }
}

data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
