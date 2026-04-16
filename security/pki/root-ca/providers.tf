terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "glab:managed-by" = "tofu"
      "glab:stack"      = "security/pki/root-ca"
    }
  }
}
