provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "glab:managed-by" = "tofu"
      "glab:stack"      = "aws/github-token-broker"
    }
  }
}
