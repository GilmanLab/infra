data "aws_lambda_function" "github_token_broker" {
  function_name = var.github_token_broker_function_name
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
