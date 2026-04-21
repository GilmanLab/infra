data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "subnet_router_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "subnet_router_tailscale_outbound_federation" {
  statement {
    sid       = "AllowGetWebIdentityTokenForTailscale"
    actions   = ["sts:GetWebIdentityToken"]
    resources = ["*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "sts:IdentityTokenAudience"
      values   = [var.tailscale_audience]
    }

    condition {
      test     = "NumericLessThanEquals"
      variable = "sts:DurationSeconds"
      values   = ["300"]
    }
  }
}

data "aws_iam_policy_document" "subnet_router_dns_mirror_route53" {
  statement {
    sid = "AllowReadMirroredHostedZone"
    actions = [
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.dns_mirror_hosted_zone_id}",
    ]
  }
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
