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

data "aws_iam_policy_document" "keycloak_acme_route53" {
  statement {
    sid = "AllowAcmeChangePolling"
    actions = [
      "route53:GetChange",
    ]
    resources = [
      "arn:aws:route53:::change/*",
    ]
  }

  statement {
    sid = "AllowAcmeZoneDiscovery"
    actions = [
      "route53:ListHostedZonesByName",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowReadAcmeZoneRecords"
    actions = [
      "route53:ListResourceRecordSets",
    ]
    resources = [
      data.aws_route53_zone.acme.arn,
    ]
  }

  statement {
    sid = "AllowWriteAcmeChallengeTxt"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = [
      data.aws_route53_zone.acme.arn,
    ]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values = [
        local.acme_challenge_record_name,
      ]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values = [
        "TXT",
      ]
    }
  }
}

data "aws_route53_zone" "private" {
  name         = var.private_zone_name
  private_zone = true
}

data "aws_route53_zone" "acme" {
  name         = var.acme_zone_name
  private_zone = false
}

data "aws_route_table" "public" {
  filter {
    name   = "tag:Name"
    values = [var.public_route_table_name]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = var.ami_ssm_parameter_name
}

data "aws_instance" "subnet_router" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_router_instance_name]
  }
}

data "aws_network_interface" "subnet_router" {
  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instance.subnet_router.id]
  }

  filter {
    name   = "attachment.device-index"
    values = ["0"]
  }
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
